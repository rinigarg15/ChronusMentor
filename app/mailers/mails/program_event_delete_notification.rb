class ProgramEventDeleteNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'pi9o9afm', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::COMMUNITY,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::EVENTS,
    :title        => Proc.new{|program| "email_translations.program_event_delete_notification.title_v1".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.program_event_delete_notification.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.program_event_delete_notification.subject".translate},
    :campaign_id  => CampaignConstants::COMMUNITY_MAIL_ID,
    :feature      => FeatureName::PROGRAM_EVENTS,
    :campaign_id_2  => CampaignConstants::PROGRAM_EVENT_DELETE_NOTIFICATION_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 4,
    :other_registered_tags => [:calendar_ics_attachment_tag]
  }

  def program_event_delete_notification(user, options={})
    @user = user
    @owner_name = options[:owner]
    @event_title = options[:title][locale] || options[:title][I18n.default_locale]
    @member = @user.member
    @event_time = get_time_for_time_zone(options[:start_time], user.member.get_valid_time_zone, "full_display_no_time_with_day".to_sym)
    @program_event_location = options[:location]
    @attachment = options[:ics_calendar_attachment] if options[:ics_calendar_attachment].present?
    @calendar_details = options.slice(:created_at, :program_event_id, :start_time, :title, :program_id)
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@user.program)
    set_username(@user)
    setup_email(@user, :from => :admin)
    set_program_event_icalendar_body_for_deletion(@calendar_details)
    super
    set_layout_options(:show_change_notif_link => true)
  end

  register_tags do
    tag :program_event_owner_name, :description => Proc.new{'email_translations.program_event_delete_notification.tags.program_event_owner_name.description'.translate}, :example => Proc.new{'William Smith'} do
      @owner_name
    end

    tag :program_event_title, :description => Proc.new{'email_translations.program_event_delete_notification.tags.program_event_title.description'.translate}, :example => Proc.new{'email_translations.program_event_delete_notification.tags.program_event_title.example'.translate} do
      @event_title
    end

    tag :event_time, :description => Proc.new{'email_translations.program_event_delete_notification.tags.event_time.description'.translate}, :example => Proc.new{'email_translations.program_event_delete_notification.tags.event_time.example'.translate} do
      @event_time
    end

    tag :program_event_location, :description => Proc.new{'email_translations.program_event_delete_notification.tags.program_event_location.description'.translate}, :example => Proc.new{'email_translations.program_event_delete_notification.tags.program_event_location.example'.translate} do
      @program_event_location
    end
  end

  self.register!

end
