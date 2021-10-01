class MeetingEditNotificationToSelf < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'xo8j8ewh', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MEETINGS,
    :title        => Proc.new{|program| "email_translations.meeting_edit_notification_to_self.title".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.meeting_edit_notification_to_self.description".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.meeting_edit_notification_to_self.subject".translate},
    :campaign_id  => CampaignConstants::ENGAGEMENT_MAIL_ID,
    :campaign_id_2  => CampaignConstants::MEETING_EDIT_NOTIFICATION_TO_SELF_MAIL_ID,
    :feature      => [FeatureName::CALENDAR, FeatureName::MENTORING_CONNECTION_MEETING],
    :program_settings => Proc.new{|program| program.calendar_sync_enabled?},
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :other_registered_tags => [:meeting_tags, :meeting_attachment_tag, :meeting_rescudule_button_tags],
    :listing_order => 7
  }

  def meeting_edit_notification_to_self(user, meeting, ics_attachment, current_occurrence_time = nil)
    @user = user
    @member = user.member
    @meeting = meeting
    @current_occurrence_time = current_occurrence_time
    @attachment = ics_attachment
    init_mail
    render_mail
  end

  private

  def init_mail
    set_username(@member)
    set_program(@meeting.program)
    set_icalendar_body(@meeting, user: @user)
    setup_email(@user)
    super
  end

  self.register!

end