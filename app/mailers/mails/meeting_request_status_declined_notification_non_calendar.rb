class MeetingRequestStatusDeclinedNotificationNonCalendar < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'w05v2w9c', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MEETING_REQUEST_RELATED,
    :title        => Proc.new{|program| "email_translations.meeting_request_status_declined_notification_non_calendar.title_v3".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.meeting_request_status_declined_notification_non_calendar.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.meeting_request_status_declined_notification_non_calendar.subject_v4".translate},
    :campaign_id  => CampaignConstants::MENTORING_REQUESTS_OFFERS_MAIL_ID,
    :campaign_id_2  => CampaignConstants::MEETING_REQUEST_STATUS_DECLINED_NOTIFICATION_NON_CALENDAR_MAIL_ID,
    :feature      => FeatureName::CALENDAR,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :other_registered_tags => [:meeting_request_tags, :meeting_request_status_sender_name_tag, :meeting_request_content_tags, :recommended_mentors_tag, :admin_and_mentor_url_tags],
    :listing_order => 9
  }

  def meeting_request_status_declined_notification_non_calendar(receiver, meeting_request, options = {})
    @receiver = receiver
    @mentee = receiver
    @request = meeting_request
    @member = @receiver.member
    @meeting_request = meeting_request
    @meeting = @meeting_request.get_meeting
    @mentor = meeting_request.mentor
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
    tag :meeting_request_creator_email, :description => Proc.new{'email_translations.meeting_request_status_declined_notification_non_calendar.tags.meeting_request_creator_email.description'.translate}, :example => Proc.new{'john@gmail.com'} do
      @meeting_request.student.email
    end

    tag :meeting_request_recepient_email, :description => Proc.new{'email_translations.meeting_request_status_declined_notification_non_calendar.tags.meeting_request_recepient_email.description'.translate}, :example => Proc.new{'john@gmail.com'} do
      @mentor.email
    end

    tag :view_all_mentors_button, :description => Proc.new{'email_translations.meeting_request_status_declined_notification_non_calendar.tags.view_all_mentors_button.description'.translate}, :example => Proc.new{ |program| call_to_action_example('email_translations.meeting_request_status_declined_notification_non_calendar.view_all_mentors_text'.translate(:mentors_term => program.find_role(RoleConstants::MENTOR_NAME).customized_term.pluralized_term_downcase)) } do
      call_to_action('email_translations.meeting_request_status_declined_notification_non_calendar.view_all_mentors_text'.translate(:mentors_term => @_mentors_string), users_url(:subdomain => @organization.subdomain, :root => @meeting_request.program.root, src: EngagementIndex::Src::BrowseMentors::EMAIL))
    end

    tag :message_from_mentor, :description => Proc.new{'email_translations.meeting_request_status_declined_notification_non_calendar.tags.message_from_mentor.description'.translate }, :example => Proc.new{'feature.email.tags.message_from_user_v3_html'.translate(:message => 'email_translations.meeting_request_status_declined_notification.tags.message_from_mentor.example'.translate, :name => 'feature.email.tags.mentor_name.example'.translate)} do
      @meeting_request.response_text.present? ? 'feature.email.tags.message_from_user_v3_html'.translate(:message => @meeting_request.response_text, :name => @mentor.name) : ""
    end
  end

  self.register!
end