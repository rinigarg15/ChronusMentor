class MeetingRequestStatusWithdrawnNotificationNonCalendar < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => '1vfz71pu', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MEETING_REQUEST_RELATED,
    :title        => Proc.new{|program| "email_translations.meeting_request_status_withdrawn_notification_non_calendar.title_v3".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.meeting_request_status_withdrawn_notification_non_calendar.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.meeting_request_status_withdrawn_notification_non_calendar.subject_v2".translate},
    :campaign_id  => CampaignConstants::MENTORING_REQUESTS_OFFERS_MAIL_ID,
    :campaign_id_2  => CampaignConstants::MEETING_REQUEST_STATUS_WITHDRAWN_NOTIFICATION_NON_CALENDAR_MAIL_ID,
    :feature      => FeatureName::CALENDAR,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :other_registered_tags => [:meeting_request_tags, :meeting_request_status_sender_name_tag, :meeting_request_content_tags],
    :listing_order => 11
  }

  def meeting_request_status_withdrawn_notification_non_calendar(receiver, meeting_request, options = {})
    @receiver = receiver
    @member = @receiver.member
    @meeting_request = meeting_request
    @meeting = @meeting_request.get_meeting
    @options = options
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@meeting_request.program)
    set_sender(@options)
    set_username(@receiver, name_only: true)
    setup_email(@receiver, from: @sender.name, sender_name: @sender.visible_to?(@receiver) ? meeting_request_status_sender_name : nil, message_type: EmailCustomization::MessageType::COMMUNICATION)
    super
    set_layout_options(:show_change_notif_link => true)
  end

  register_tags do
    tag :meeting_request_creator_email, :description => Proc.new{'email_translations.meeting_request_status_withdrawn_notification_non_calendar.tags.meeting_request_creator_email.description'.translate}, :example => Proc.new{'john@gmail.com'} do
      @meeting_request.student.email
    end

    tag :meeting_request_recepient_email, :description => Proc.new{'email_translations.meeting_request_status_withdrawn_notification_non_calendar.tags.meeting_request_recepient_email.description'.translate}, :example => Proc.new{'john@gmail.com'} do
      @meeting_request.mentor.email
    end

    tag :meeting_description_as_quote, :description => Proc.new{'email_translations.meeting_request_status_withdrawn_notification_non_calendar.tags.meeting_description_as_quote.description'.translate}, :example => Proc.new{'feature.email.tags.message_from_user_v3_html'.translate(:message => 'feature.email.tags.meeting_tags.meeting_description.example'.translate, :name => 'feature.email.tags.mentor_name.example'.translate)} do
      word_wrap(@meeting.description.present? ? 'feature.email.tags.message_from_user_v3_html'.translate(:message => @meeting.description, :name => meeting_request_status_sender_name) : "").html_safe
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.meeting_request_status_withdrawn_notification_non_calendar.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@program, url_params: { subdomain: @organization.subdomain, root: @program.root }, only_url: true)
    end

    tag :meeting_send_date, :description => Proc.new{'email_translations.meeting_request_status_withdrawn_notification_non_calendar.tags.meeting_send_date.description'.translate}, :example => Proc.new{'email_translations.meeting_request_status_withdrawn_notification_non_calendar.tags.meeting_send_date.example'.translate} do
      DateTime.localize(@meeting_request.created_at.in_time_zone(@member.get_valid_time_zone), format: :full_display_no_time)
    end

  end

  self.register!
end