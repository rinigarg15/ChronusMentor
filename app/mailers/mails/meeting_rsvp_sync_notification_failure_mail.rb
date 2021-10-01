class MeetingRsvpSyncNotificationFailureMail < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => '6dclw7mq', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MEETINGS,
    :title        => Proc.new{|program| "email_translations.meeting_rsvp_sync_notification_failure_mail.title".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.meeting_rsvp_sync_notification_failure_mail.description".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.meeting_rsvp_sync_notification_failure_mail.subject".translate},
    :campaign_id  => CampaignConstants::ENGAGEMENT_MAIL_ID,
    :campaign_id_2  => CampaignConstants::MEETING_RSVP_SYNC_NOTIFICATION_FAILURE_MAIL_ID,
    :feature      => [FeatureName::CALENDAR, FeatureName::MENTORING_CONNECTION_MEETING],
    :program_settings => Proc.new{|program| program.calendar_sync_enabled?},
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :other_registered_tags => [:meeting_tags],
    :listing_order => 5,
    :donot_list   => true
  }

  def meeting_rsvp_sync_notification_failure_mail(user, meeting)
    @user = user
    @member = user.member
    @meeting = meeting
    @hide_attendee_rsvp = true
    init_mail
    render_mail
  end

  private

  def init_mail
    set_username(@member)
    set_program(@meeting.program)
    setup_email(@user)
    super
  end


  register_tags do
    tag :meetings_listing_url, :description => Proc.new{|program| "email_translations.meeting_rsvp_sync_notification_failure_mail.tags.meetings_listing_url.description".translate(program.return_custom_term_hash)}, :example => Proc.new{"http://www.chronus.com"} do
      meetings_url(subdomain: @organization.subdomain, root: @program.root, group_id: @meeting.group.id, src: "email")
    end
  end

  self.register!

end
