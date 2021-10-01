class Calendar::GoogleApi
  require 'google/apis/calendar_v3'
  require 'googleauth'
  require 'googleauth/stores/file_token_store'

  require 'fileutils'

  OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'

  APPLICATION_NAME = 'Google Calendar API Mentor'

  CALENDAR_ID = 'primary'

  SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR
  CLIENT_SECRET_FILENAME = "calendar_api_client_secret.json"
  CREDENTIALS_FILENAME = "calendar_api_credentials.yaml"

  API_RETRY_COUNT = 3
  SYNC_ACCOUNT_LIMIT_REACHED_MESSAGE_REGEX = /Calendar usage limits exceeded/

  def initialize(account_id)
    @service = self.class.get_calendar_service(account_id)
  end

  def self.get_authorization_credentials(account_id)
    authorizer = self.get_service_authorizer(account_id)
    credentials = authorizer.get_credentials('default')
    if credentials.nil?
      #authorize method should be run again manually in this case.
      Airbrake.notify("Google calendar api authorization failed. reauthorize again manually from the console")
    end
    credentials
  end

  def self.authorize(account_id)
    #This method should be run manually from the console after logging in to the server, once this is done authorization information is stored on file system in the server. so subsequent executions will not prompt for authorization.
    authorizer = self.get_service_authorizer(account_id)
    url = authorizer.get_authorization_url(
      base_url: Calendar::GoogleApi::OOB_URI)
    puts "Open the following URL in the browser and enter the " +
         "resulting code after authorization"
    puts url
    code = gets
    authorizer.get_and_store_credentials_from_code(
      user_id: 'default', code: code, base_url: Calendar::GoogleApi::OOB_URI)
  end

  def self.get_client_secret_path(options = {})
    Rails.env.test? ? APP_CONFIG[:calendar_api_client_secret_path] : File.join(options[:root_path], CLIENT_SECRET_FILENAME)
  end

  def self.get_api_credentials_path(options = {})
    Rails.env.test? ? APP_CONFIG[:calendar_api_credentials_path] : File.join(options[:root_path], CREDENTIALS_FILENAME)
  end

  def self.get_credentials_root_path(account_id)
    File.join(CALENDAR_API_CREDS_DIR, account_id.split("@").first)
  end

  def self.get_service_authorizer(account_id)
    root_path = self.get_credentials_root_path(account_id)
    credentials_path = self.get_api_credentials_path(root_path: root_path)
    client_id = Google::Auth::ClientId.from_file(self.get_client_secret_path(root_path: root_path))
    token_store = Google::Auth::Stores::FileTokenStore.new(file: credentials_path)
    authorizer = Google::Auth::UserAuthorizer.new(
      client_id, SCOPE, token_store)
    authorizer
  end

  def self.get_calendar_service(account_id)
    service = Google::Apis::CalendarV3::CalendarService.new
    service.client_options.application_name = APPLICATION_NAME
    service.authorization = get_authorization_credentials(account_id)
    service
  end

  def establish_new_notification_channel(scheduling_account)
    stop_notification_channel(scheduling_account)
    create_notification_channel(scheduling_account)
  end

  def insert_calendar_event(options)
    event = build_calendar_event(options)
    begin
      attendees = options[:attendees]
      calendar_event = @service.insert_event(CALENDAR_ID, event)

      if attendees.present?
        calendar_event.attendees = attendees
        calendar_event = @service.update_event(CALENDAR_ID, calendar_event.id, calendar_event)
      end
    rescue => e
      CalendarSyncErrorCases.create_error_case(CalendarSyncErrorCases::ScenarioType::EVENT_CREATE, options.merge(error_message: e.message))
      Airbrake.notify("Calendar event insertion failed after trying for #{API_RETRY_COUNT} times at #{Time.now} Exception: #{e.message}")

      if e.message =~ SYNC_ACCOUNT_LIMIT_REACHED_MESSAGE_REGEX
        Airbrake.notify("Scheduling Account with email #{options[:scheduling_assistant_email]} has been deactivated.")
        SchedulingAccount.find_by(email: options[:scheduling_assistant_email]).update_column(:status, SchedulingAccount::Status::INACTIVE)
      end
    end
    return calendar_event
  end

  def remove_calendar_event(event_id, delete_try_count = API_RETRY_COUNT)
    begin
      @service.delete_event(CALENDAR_ID, event_id)
    rescue => e
      if delete_try_count > 0
        remove_calendar_event(event_id, delete_try_count - 1)
      else
        CalendarSyncErrorCases.create_error_case(CalendarSyncErrorCases::ScenarioType::EVENT_DELETE, {event_id: event_id, error_message: e.message})
        Airbrake.notify("Calendar event deletion failed after trying for #{API_RETRY_COUNT} times at #{Time.now} Exception: #{e.message}")
      end
    end
  end

  def update_calendar_event(options, event_id, update_try_count = API_RETRY_COUNT)
    begin
      event = @service.get_event(CALENDAR_ID, event_id)
      attendees = options[:attendees]

      event = get_updated_event(event, options)
      event = @service.update_event(CALENDAR_ID, event.id, event)

      if attendees.present?
        event.attendees = attendees
        @service.update_event(CALENDAR_ID, event.id, event)
      end
    rescue => e
      if update_try_count > 0
        update_calendar_event(options, event_id, update_try_count - 1)
      else
        CalendarSyncErrorCases.create_error_case(CalendarSyncErrorCases::ScenarioType::EVENT_UPDATE, options.merge(event_id: event_id, error_message: e.message))
        Airbrake.notify("Calendar event updation failed after trying for #{API_RETRY_COUNT} times at #{Time.now} Exception: #{e.message}")
      end
    end
  end

  def perform_rsvp_sync(sync_notification_time, notification_channel, sync_try_count = API_RETRY_COUNT)
    notification_channel.update_attribute(:last_sync_time, Time.now)

    scheduling_account_email = notification_channel.scheduling_account.email

    sync_token = notification_channel.last_sync_token
    page_token = nil
    next_sync_token = nil
    response_items = []

    loop do
      params_hash = get_event_listing_parameters
      params_hash.merge!(sync_token: sync_token) if sync_token.present?
      params_hash.merge!(page_token: page_token) if page_token.present?

      begin
        response = @service.list_events(CALENDAR_ID, params_hash)
        response_items += response.items if response.items.present?
        page_token = response.next_page_token
        next_sync_token = response.next_sync_token

        if page_token.blank?
          if response_items.present?
            begin
              CalendarSyncRsvpLogs.create_rsvp_sync_log(response_items)
            rescue => e
              Airbrake.notify("Could not capture calendar rsvp sync logs at #{Time.now} Exception: #{e.message}")
            end
            Meeting.perform_rsvp_sync_from_calendar_to_app(response_items, scheduling_account_email)
          end
          break
        end
      rescue => e
        if sync_try_count > 0
          return perform_rsvp_sync(sync_notification_time, notification_channel, sync_try_count - 1)
        else
          notification_channel.update_attribute(:last_sync_token, nil)
          CalendarSyncErrorCases.create_error_case(CalendarSyncErrorCases::ScenarioType::RSVP_SYNC, {sync_notification_time: sync_notification_time, error_message: e.message, notification_channel_id: notification_channel.id})
          Airbrake.notify("Calendar sync failed after trying for #{API_RETRY_COUNT} times at #{Time.now} for channel id #{notification_channel.id} Exception: #{e.message}")
          break
        end
      end
    end

    notification_channel.update_attribute(:last_sync_token, next_sync_token)

    if notification_channel.reload.last_notification_received_on.to_i > sync_notification_time.to_i
      Meeting.delay(queue: DjQueues::HIGH_PRIORITY).send("start_rsvp_sync_#{notification_channel.id}", Time.now)
    end
  end

  private

  def get_updated_event(event, options)
    event.attendees = options[:attendees] if options[:attendees].present?
    event.description = options[:description] if options[:description].present?
    event.summary = options[:topic] if options[:topic].present?
    event.location = options[:location] if options[:location].present?
    event.start = { date_time: options[:start_time], time_zone: options[:time_zone] } if options[:start_time].present?
    event.end = { date_time: options[:end_time], time_zone: options[:time_zone] } if options[:end_time].present?
    event.sequence = options[:sequence] if options[:sequence].present?
    event.recurrence = options[:recurrence] if options[:recurrence].present?
    return event
  end

  def get_event_listing_parameters
    {single_events: true}
  end

  def stop_notification_channel(scheduling_account)
    last_notification_channel = scheduling_account.calendar_sync_notification_channels.last
    
    if last_notification_channel.present? && last_notification_channel.expiration_time > Time.now
      channel = Google::Apis::CalendarV3::Channel.new(
        id: last_notification_channel.channel_id,
        resource_id: last_notification_channel.resource_id
      )
      @service.stop_channel(channel)
    end
  end

  def create_notification_channel(scheduling_account)
    channel_id = SecureRandom.uuid
    expiration = (Time.now + 1.week).to_i*1000

    channel = Google::Apis::CalendarV3::Channel.new(address: CALENDAR_SYNC_NOTIFICATION_URL, id: channel_id, type: "web_hook", expiration: expiration)

    watch_response = @service.watch_event(CALENDAR_ID, channel)

    if watch_response.try(:kind) == "api#channel" && watch_response.try(:id) == channel_id
      expiration = DateTime.strptime(watch_response.expiration, "time.formats.milliseconds".translate)
      resource_id = watch_response.resource_id

      last_notification_channel = scheduling_account.calendar_sync_notification_channels.last
      last_sync_token = last_notification_channel.present? ? last_notification_channel.last_sync_token : nil

      CalendarSyncNotificationChannel.create!(channel_id: channel_id, resource_id: resource_id, expiration_time: expiration, last_sync_token: last_sync_token, scheduling_account_id: scheduling_account.id)
    end
  end

  def build_calendar_event(options)
    event = Google::Apis::CalendarV3::Event.new({
      i_cal_uid: options[:id],
      summary: options[:topic],
      location: options[:location],
      description: options[:description],
      start: {
        date_time: options[:start_time],
        time_zone: options[:time_zone]
      },
      end: {
        date_time: options[:end_time],
        time_zone: options[:time_zone]
      },
      recurrence: options[:recurrence],
      reminders: {
        use_default: true
      },
      organizer: {
        email: options[:scheduling_assistant_email],
        displayName: APP_CONFIG[:scheduling_assistant_display_name]
      },
      guests_can_see_other_guests: options[:guests_can_see_other_guests],
      sequence: options[:sequence]
    })
    return event

  end
end