class ProgramEventReminderNotification < ChronusActionMailer::Base
  include ProgramEventsHelper

  @mailer_attributes = {
    :uid          => 'uu5iysuo', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::COMMUNITY,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::EVENTS,
    :title        => Proc.new{|program| "email_translations.program_event_reminder_notification.title_v1".translate(program.return_custom_term_hash)},
    :description  => Proc.new{"email_translations.program_event_reminder_notification.description_v1".translate},
    :subject      => Proc.new{"email_translations.program_event_reminder_notification.subject_v3".translate},
    :campaign_id  => CampaignConstants::COMMUNITY_MAIL_ID,
    :feature      => FeatureName::PROGRAM_EVENTS,
    :campaign_id_2  => CampaignConstants::PROGRAM_EVENT_REMINDER_NOTIFICATION_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 3
  }

  def program_event_reminder_notification(user, program_event)
    @program_event = program_event
    @user = user
    @member = @user.member
    @event_timings = event_time_for_display(@program_event, @member)
    @event_datetime = event_datetime_for_display_in_email(@program_event, @member)
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@program_event.program)
    set_username(@user)
    setup_email(@user, :from => :admin)
    super
    set_layout_options(:show_change_notif_link => true)
  end

  register_tags do
    tag :program_event_title, :description => Proc.new{'email_translations.program_event_reminder_notification.tags.program_event_title.description'.translate}, :example => Proc.new{'email_translations.program_event_reminder_notification.tags.program_event_title.example'.translate} do
      @program_event.title
    end

    tag :program_event_start_time, :description => Proc.new{'email_translations.program_event_reminder_notification.tags.program_event_start_time.description'.translate}, :example => Proc.new{'email_translations.program_event_reminder_notification.tags.program_event_start_time.example'.translate} do
      event_time = DateTime.localize(@program_event.start_time.in_time_zone(@member.get_valid_time_zone), format: :short_date_short_time)
      event_time
    end

    tag :event_start_time, :description => Proc.new{'email_translations.program_event_reminder_notification.tags.event_start_time.description'.translate}, :example => Proc.new{'email_translations.program_event_reminder_notification.tags.event_start_time.example'.translate} do
      event_time = DateTime.localize(@program_event.start_time.in_time_zone(@member.time_zone.presence || @program_event.time_zone.presence || TimezoneConstants::DEFAULT_TIMEZONE), format: :short_date_short_time)
      event_time
    end

    tag :program_event_timings, :description => Proc.new{'email_translations.program_event_reminder_notification.tags.program_event_timings.description'.translate}, :example => Proc.new{'email_translations.program_event_reminder_notification.tags.program_event_timings.example'.translate} do
      get_time_for_time_zone(@program_event.start_time, @member.get_valid_time_zone, "short".to_sym) + " " + @event_timings
    end

    tag :event_time, :description => Proc.new{'email_translations.program_event_reminder_notification.tags.event_time.description'.translate}, :example => Proc.new{'email_translations.program_event_reminder_notification.tags.event_time.example'.translate} do
      @event_datetime
    end

    tag :program_event_location, :description => Proc.new{'email_translations.program_event_reminder_notification.tags.program_event_location.description'.translate}, :example => Proc.new{'email_translations.program_event_reminder_notification.tags.program_event_location.example'.translate} do
      @program_event.location.presence || "-"
    end

    tag :url_program_event, :description => Proc.new{'email_translations.program_event_reminder_notification.tags.url_program_event.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      program_event_url(@program_event, :subdomain => @organization.subdomain)
    end     

    tag :view_event_details_button, :description => Proc.new{'email_translations.program_event_reminder_notification.tags.view_event_details_button.description'.translate}, :example => Proc.new{ call_to_action_example("email_translations.program_event_reminder_notification.tags.view_event_details_button.view_event_details".translate) } do
      call_to_action("email_translations.program_event_reminder_notification.tags.view_event_details_button.view_event_details".translate, program_event_url(@program_event, :subdomain => @organization.subdomain))
    end      

  end

  self.register!

end