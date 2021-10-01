class MeetingReminder < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => '6s95xwmd', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MEETINGS,
    :title        => Proc.new{|program| "email_translations.meeting_reminder.title_v4".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.meeting_reminder.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.meeting_reminder.subject_v2".translate},
    :campaign_id  => CampaignConstants::ENGAGEMENT_MAIL_ID,
    :campaign_id_2  => CampaignConstants::MEETING_REMINDER_MAIL_ID,
    :feature      => [FeatureName::CALENDAR, FeatureName::MENTORING_CONNECTION_MEETING],
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :other_registered_tags => [:meeting_tags, :meeting_member_response_tag, :reply_to_tags, :meeting_rescudule_button_tags],
    :listing_order => 10
  }

  def meeting_reminder(user, member_meeting, current_occurrence_time = nil)
    @user = user
    @member = user.member
    @member_meeting = member_meeting
    @meeting = member_meeting.meeting
    @current_occurrence_time = current_occurrence_time
    init_mail
    render_mail
  end

  private

  def init_mail
    set_username(@member)
    set_program(@meeting.program)
    @is_reply_enabled = true
    @reply_to = [MAILER_ACCOUNT[:reply_to_address].call("-#{@member_meeting.api_token}", ReplyViaEmail::MEETING_REMINDER_NOTIFICATION)]
    setup_email(@user)
    super
  end

  self.register!

end
