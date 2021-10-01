class MeetingRequestCreatedNotificationNonCalendar < ChronusActionMailer::Base
  
  @mailer_attributes = {
    :uid          => 'odwveev7', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MEETING_REQUEST_RELATED,
    :title        => Proc.new{|program| "email_translations.meeting_request_created_notification_non_calendar.title_v3".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.meeting_request_created_notification_non_calendar.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.meeting_request_created_notification_non_calendar.subject_v2".translate},
    :campaign_id  => CampaignConstants::MENTORING_REQUESTS_OFFERS_MAIL_ID,
    :campaign_id_2  => CampaignConstants::MEETING_REQUEST_CREATED_NOTIFICATION_NON_CALENDAR_MAIL_ID,
    :feature      => FeatureName::CALENDAR,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :other_registered_tags => [:meeting_request_tags, :meeting_request_action_tags, :meeting_request_created_tags],
    :listing_order => 2
  }

  def meeting_request_created_notification_non_calendar(user, meeting_request, options={})
    @receiver = user
    @member = user.member
    @meeting_request = meeting_request
    @meeting = @meeting_request.get_meeting
    @options = options
    @sender_visible_to_receiver = @meeting_request.student.visible_to?(@receiver)
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@meeting_request.program)
    set_sender(@options)
    set_username(@receiver, :name_only => true)
    setup_email(@receiver, sender_name: @sender_visible_to_receiver ? meeting_request_creator_name : nil, message_type: EmailCustomization::MessageType::COMMUNICATION)
    super
    set_layout_options(:show_change_notif_link => true)
  end

  register_tags do
    tag :meeting_request_creator_email, :description => Proc.new{'email_translations.meeting_request_created_notification_non_calendar.tags.meeting_request_creator_email.description'.translate}, :example => Proc.new{'john@gmail.com'} do
      @meeting_request.student.email
    end

    tag :meeting_request_recepient_email, :description => Proc.new{'email_translations.meeting_request_created_notification_non_calendar.tags.meeting_request_recepient_email.description'.translate}, :example => Proc.new{'john@gmail.com'} do
      @meeting_request.mentor.email
    end

    tag :mentee_name, description: Proc.new{'email_translations.meeting_request_created_notification_non_calendar.tags.mentee_name.description'.translate}, example: Proc.new{'feature.email.tags.mentor_name.example'.translate} do
      @meeting_request.student.name(name_only: true)
    end

    tag :meeting_description_as_quote, :description => Proc.new{'email_translations.meeting_request_created_notification_non_calendar.tags.meeting_description_as_quote.description'.translate}, :example => Proc.new{'feature.email.tags.message_from_user_v3_html'.translate(:message => 'feature.email.tags.meeting_tags.meeting_description.example'.translate, :name => 'feature.email.tags.mentor_name.example'.translate)} do
      word_wrap(@meeting.description.present? ? 'feature.email.tags.message_from_user_v3_html'.translate(:message => @meeting.description, :name => mentee_name) : "").html_safe
    end

    tag :view_request_button, description: Proc.new{'email_translations.meeting_request_created_notification_non_calendar.tags.view_request_button.description'.translate}, example: Proc.new{ call_to_action_example('email_translations.meeting_request_created_notification_non_calendar.view_request_text'.translate) } do
      call_to_action('email_translations.meeting_request_created_notification_non_calendar.view_request_text'.translate, meeting_requests_url(root: @program.root, :subdomain => @program.organization.subdomain))
    end

    tag :mentee_url, :description => Proc.new{'feature.email.tags.meeting_tags.mentee_url.description'.translate}, :example => Proc.new{'feature.email.tags.mentor_name.example_with_url'.translate} do
      link_to(@meeting_request.student.name, user_url(@meeting_request.student, :subdomain => @organization.subdomain, :root => @program.root))
    end
  end

  self.register!
end
