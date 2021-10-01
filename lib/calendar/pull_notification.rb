class Calendar::PullNotification
  MAX_MAILGUN_EVENTS = 100
  STORED_EVENT = "stored"
  KLASS_REPLY_TO_PREFIX_MAP = { Meeting => APP_CONFIG[:reply_to_calendar_notification], ProgramEvent => APP_CONFIG[:reply_to_program_event_calendar_notification] }

  def initialize
    @start_time = (Time.now - 1.day).utc.to_i
    @end_time = Time.now.utc.to_i
    @mg_client = Mailgun::Client.new(APP_CONFIG[:mailgun_api_key])
    @mg_events = Mailgun::Events.new(@mg_client, MAILGUN_DOMAIN)
  end

  def update_meetings_and_program_events_with_calendars
    pull_message_urls_grouped_by_klass.each do |klass, message_urls|
      BlockExecutor.iterate_fail_safe(message_urls) do |_recipient_email, url|
        resource = RestClient::Resource.new(url, user: 'api', password: APP_CONFIG[:mailgun_api_key], user_agent: "mailgun-sdk-ruby/#{Mailgun::VERSION}")
        body = JSON.parse(resource.get(accept: "*/*").body)
        klass.update_rsvp_with_calendar(CalendarUtils.get_email_address(body["To"]), body["body-calendar"])
      end
    end
  end

  private

  def pull_message_urls_grouped_by_klass
    message_urls_klass_map = {}
    result = @mg_events.get({
      limit: MAX_MAILGUN_EVENTS,
      begin: @start_time,
      end: @end_time,
      ascending: "yes",
      event: STORED_EVENT
    })
    # We are using a hash so as to ignore the previous replies from an user in case he replied many times during the day.
    # We are using recipient_email+sender_email as the key to uniquely identify single user in case more than 1 attendee responded in the same day
    while (items_array = result.to_h['items']).present?
      items_array.each do |item|
        recipient_email, sender_email = get_from_to_address(item)
        KLASS_REPLY_TO_PREFIX_MAP.each do |klass, reply_to_prefix|
          message_urls_klass_map[klass] ||= {}
          message_urls_klass_map[klass][recipient_email + sender_email] = item["storage"]["url"] if CalendarUtils.match_organizer_email(recipient_email, reply_to_prefix).present?
        end
      end
      result = @mg_events.next
    end
    message_urls_klass_map
  end

  def get_from_to_address(item)
    return CalendarUtils.get_email_address(item["message"]["recipients"][0]), CalendarUtils.get_email_address(item["message"]["headers"]["from"])
  end
end