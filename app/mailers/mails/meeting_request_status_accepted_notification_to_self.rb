class MeetingRequestStatusAcceptedNotificationToSelf < ChronusActionMailer::Base
  @mailer_attributes = {
    :uid          => 'z67pfutp', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MEETING_REQUEST_RELATED,
    :title        => Proc.new{|program| "email_translations.meeting_request_status_accepted_notification_to_self.title_v4".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.meeting_request_status_accepted_notification_to_self.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.meeting_request_status_accepted_notification_to_self.subject_v3".translate},
    :campaign_id  => CampaignConstants::MENTORING_REQUESTS_OFFERS_MAIL_ID,
    :campaign_id_2  => CampaignConstants::MEETING_REQUEST_STATUS_ACCEPTED_NOTIFICATION_TO_SELF_MAIL_ID,
    :feature      => FeatureName::CALENDAR,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{ |program| program.calendar_setting.allow_mentor_to_configure_availability_slots? },
    :level        => EmailCustomization::Level::PROGRAM,
    :other_registered_tags => [:meeting_request_tags, :meeting_attachment_tag, :meeting_tags, :meeting_request_status_sender_name_tag],
    :listing_order => 7
  }

  def meeting_request_status_accepted_notification_to_self(receiver, sender, meeting_request, ics_attachment)
    @sender = sender
    @sender_name = @sender.name
    @receiver = receiver
    @member = @receiver.member
    @meeting_request = meeting_request
    @meeting = @meeting_request.get_meeting
    @attachment = ics_attachment
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@meeting_request.program)
    set_username(@receiver, name_only: true)
    set_icalendar_body(@meeting, user: @receiver)
    setup_email(@receiver)
    super
    set_layout_options(:show_change_notif_link => true)
  end

  register_tags do
    tag :meeting_request_creator_email, :description => Proc.new{'email_translations.meeting_request_status_accepted_notification_to_self.tags.meeting_request_creator_email.description'.translate}, :example => Proc.new{'john@gmail.com'} do
      @meeting_request.student.email
    end

    tag :meeting_request_recepient_email, :description => Proc.new{'email_translations.meeting_request_status_accepted_notification_to_self.tags.meeting_request_recepient_email.description'.translate}, :example => Proc.new{'john@gmail.com'} do
      @meeting_request.mentor.email
    end
  end

  self.register!
end