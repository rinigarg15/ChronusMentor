class MeetingRsvpNotificationToSelf < ChronusActionMailer::Base
  @mailer_attributes = {
    :uid          => 'x026wuxo', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MEETINGS,
    :title        => Proc.new{|program| "email_translations.meeting_rsvp_notification_to_self.title".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.meeting_rsvp_notification_to_self.description".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.meeting_rsvp_notification_to_self.subject".translate},
    :campaign_id  => CampaignConstants::ENGAGEMENT_MAIL_ID,
    :campaign_id_2  => CampaignConstants::MEETING_RSVP_NOTIFICATION_TO_SELF_MAIL_ID,
    :feature      => [FeatureName::CALENDAR, FeatureName::MENTORING_CONNECTION_MEETING],
    :program_settings => Proc.new{|program| program.calendar_sync_enabled?},
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :other_registered_tags => [:meeting_tags, :meeting_rescudule_button_tags],
    :listing_order => 4
  }

  def meeting_rsvp_notification_to_self(user, member_meeting, current_occurrence_time = nil)
    @user = user
    @meeting = member_meeting.meeting
    @member = user.member
    @attendee = member_meeting.member
    @current_occurrence_time = current_occurrence_time
    @rsvp_response = @meeting.member_meetings.find_by(member_id: @attendee.id).get_response_object(@current_occurrence_time)
    init_mail
    render_mail
  end

  private

  def init_mail
    set_username(@member)
    set_program(@meeting.program)
    set_icalendar_body(@meeting, user: @user, current_occurrence_time: @current_occurrence_time)
    setup_email(@user)
    super
  end

  register_tags do
    tag :rsvp_action, :description => Proc.new{'email_translations.meeting_rsvp_notification_to_self.tags.rsvp_action.description'.translate}, :example => Proc.new{'email_translations.meeting_rsvp_notification_to_self.tags.rsvp_action.example'.translate} do
      @rsvp_response.accepted? ? 'display_string.accepted'.translate : 'display_string.declined'.translate
    end

    tag :rsvp_action_capitalized, :description => Proc.new{'email_translations.meeting_rsvp_notification_to_self.tags.rsvp_action_capitalized.description'.translate}, :example => Proc.new{'email_translations.meeting_rsvp_notification_to_self.tags.rsvp_action_capitalized.example'.translate} do
      @rsvp_response.accepted? ? 'display_string.Accepted'.translate : 'display_string.Declined'.translate
    end
  end

  self.register!

end
