class MeetingCancellationNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'rd5gbmr9', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MEETINGS,
    :title        => Proc.new{|program| "email_translations.meeting_cancellation_notification.title_v2".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.meeting_cancellation_notification.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.meeting_cancellation_notification.subject_v1".translate},
    :campaign_id  => CampaignConstants::ENGAGEMENT_MAIL_ID,
    :campaign_id_2  => CampaignConstants::MEETING_CANCELLATION_NOTIFICATION_MAIL_ID,
    :feature      => [FeatureName::CALENDAR, FeatureName::MENTORING_CONNECTION_MEETING],
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :other_registered_tags => [:meeting_tags, :meeting_attachment_tag],
    :excluded_tags => [:url_meeting],
    :listing_order => 8
  }

  def meeting_cancellation_notification(user, meeting, ics_attachment, current_occurrence_time = nil, following_occurrence_time = nil, options={})
    @user = user
    @member = user.member
    @meeting_owner = meeting.owner
    @meeting = meeting
    @current_occurrence_time = current_occurrence_time
    @following_occurrence_time = following_occurrence_time
    @attachment = ics_attachment
    @options = options
    init_mail
    render_mail
  end

  private

  def init_mail
    set_username(@member)
    set_sender(@options)
    set_program(@meeting.program)
    set_icalendar_body(@meeting, {ics_action: Meeting::IcsCalendarScenario::CANCEL_EVENT, user: @user})
    setup_email(@user, :sender_name => @meeting_owner.visible_to?(@member) ? meeting_owner_name : nil, message_type: EmailCustomization::MessageType::COMMUNICATION)
    super
  end

  self.register!

end
