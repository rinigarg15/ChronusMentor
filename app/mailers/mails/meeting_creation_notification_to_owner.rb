class MeetingCreationNotificationToOwner < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => '9i6s67ub', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MEETINGS,
    :title        => Proc.new{|program| "email_translations.meeting_creation_notification_to_owner.title_v4".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.meeting_creation_notification_to_owner.description_v4".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.meeting_creation_notification_to_owner.subject_v2".translate},
    :campaign_id  => CampaignConstants::ENGAGEMENT_MAIL_ID,
    :campaign_id_2  => CampaignConstants::MEETING_CREATION_NOTIFICATION_TO_OWNER_MAIL_ID,
    :feature      => [FeatureName::CALENDAR, FeatureName::MENTORING_CONNECTION_MEETING],
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :other_registered_tags => [:meeting_tags, :meeting_attachment_tag, :meeting_rescudule_button_tags],
    :listing_order => 2
  }

  def meeting_creation_notification_to_owner(owner, meeting, ics_attachment)
    @user = owner
    @meeting = meeting
    @member = owner.member
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
