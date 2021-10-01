class MeetingRequestStatusAcceptedNotificationNonCalendar < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'iiqviabh', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MEETING_REQUEST_RELATED,
    :title        => Proc.new{|program| "email_translations.meeting_request_status_accepted_notification_non_calendar.title_v3".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.meeting_request_status_accepted_notification_non_calendar.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.meeting_request_status_accepted_notification_non_calendar.subject_v2".translate},
    :campaign_id  => CampaignConstants::MENTORING_REQUESTS_OFFERS_MAIL_ID,
    :campaign_id_2  => CampaignConstants::MEETING_REQUEST_STATUS_ACCEPTED_NOTIFICATION_NON_CALENDAR_MAIL_ID,
    :feature      => FeatureName::CALENDAR,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :other_registered_tags => [:meeting_request_tags, :meeting_request_status_sender_name_tag, :meeting_request_accepted_tags, :meeting_request_content_tags, :reply_to_tags],
    :listing_order => 6
  }

  def meeting_request_status_accepted_notification_non_calendar(receiver, meeting_request, options = {})
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
    @is_reply_enabled = true
    @reply_to = [MAILER_ACCOUNT[:reply_to_address].call(@meeting.get_reply_to_token(@options[:sender].member.id, @member.id), ReplyViaEmail::MEETING_REQUEST_ACCEPTED_NON_CALENDAR)]
    @sender_visible_to_receiver = @sender.visible_to?(@receiver)
    setup_email(@receiver, from: @sender.name, sender_name: @sender_visible_to_receiver ? meeting_request_status_sender_name : nil)
    super
    set_layout_options(:show_change_notif_link => true)
  end

  register_tags do
    tag :meeting_request_creator_email, :description => Proc.new{'email_translations.meeting_request_status_accepted_notification_non_calendar.tags.meeting_request_creator_email.description'.translate}, :example => Proc.new{'john@gmail.com'} do
      @meeting_request.student.email
    end

    tag :meeting_request_recepient_email, :description => Proc.new{'email_translations.meeting_request_status_accepted_notification_non_calendar.tags.meeting_request_recepient_email.description'.translate}, :example => Proc.new{'john@gmail.com'} do
      @meeting_request.mentor.email
    end

    tag :message_from_mentor, :description => Proc.new{'email_translations.meeting_request_status_accepted_notification_non_calendar.tags.message_from_mentor.description'.translate}, :example => Proc.new{'email_translations.meeting_request_status_accepted_notification_non_calendar.tags.message_from_mentor.example_html'.translate} do
      @meeting_request.acceptance_message.present? ? 'feature.email.tags.message_from_user_v3_html'.translate(:message => @meeting_request.acceptance_message, :name => @meeting_request.mentor.name) : ""
    end

    tag :contextual_message, description: Proc.new{'feature.email.tags.meeting_request_tags.contextual_message.description'.translate(meeting: @_meeting_string)}, example: Proc.new{'feature.email.tags.meeting_request_tags.contextual_message.example_noncalendar_html'.translate(meeting: @_meeting_string)} do
      "feature.email.tags.meeting_request_tags.contextual_message.content_noncalendar_html".translate(name: @meeting_request.mentor.name(name_only: true), meeting: @_meeting_string, message: @meeting_request.acceptance_message)
    end

    tag :meeting_details_with_action, description: Proc.new{'feature.email.tags.meeting_request_tags.meeting_details_with_action.description'.translate(meeting: @_meeting_string)}, example: Proc.new{'feature.email.tags.meeting_request_tags.meeting_details_with_action.noncalendar_example_html'.translate(meeting_caps: @_Meeting_string)} do
      render(partial: '/meeting_details_with_action', locals: {meeting_request: @meeting_request, member: @member, user: @receiver})
    end
  end

  self.register!
end