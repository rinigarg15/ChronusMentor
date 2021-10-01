class MeetingRsvpNotification < ChronusActionMailer::Base
  @mailer_attributes = {
    :uid          => 'xg8waq2b', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MEETINGS,
    :title        => Proc.new{|program| "email_translations.meeting_rsvp_notification.title_v3".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.meeting_rsvp_notification.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.meeting_rsvp_notification.subject_v1".translate},
    :campaign_id  => CampaignConstants::ENGAGEMENT_MAIL_ID,
    :campaign_id_2  => CampaignConstants::MEETING_RSVP_NOTIFICATION_MAIL_ID,
    :feature      => [FeatureName::CALENDAR, FeatureName::MENTORING_CONNECTION_MEETING],
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :other_registered_tags => [:meeting_tags, :meeting_member_response_tag, :reply_to_tags, :meeting_rescudule_button_tags],
    :listing_order => 3
  }

  def meeting_rsvp_notification(user, member_meeting, current_occurrence_time = nil)
    @user = user
    @meeting = member_meeting.meeting
    @member = user.member
    @invitee = member_meeting.member
    @member_meeting = member_meeting
    @current_occurrence_time = current_occurrence_time
    init_mail
    render_mail
  end

  private

  def init_mail
    set_username(@member)
    set_program(@meeting.program)
    set_icalendar_body(@meeting, user: @user, current_occurrence_time: @current_occurrence_time)
    @is_reply_enabled = true
    @reply_to = [MAILER_ACCOUNT[:reply_to_address].call(@meeting.get_reply_to_token(@invitee.id, @member.id), ReplyViaEmail::MEETING_RSVP_NOTIFICATION_OWNER)]
    setup_email(@user, sender_name: @invitee.visible_to?(@member) ? invitee_name : nil)
    super
  end

  register_tags do
    tag :invitee_name, :description => Proc.new{'email_translations.meeting_rsvp_notification.tags.invitee_name.description'.translate}, :example => Proc.new{'William Smith'} do
      @invitee.name
    end

    tag :rsvp_action, :description => Proc.new{'email_translations.meeting_rsvp_notification.tags.rsvp_action.description'.translate}, :example => Proc.new{'email_translations.meeting_rsvp_notification.tags.rsvp_action.example'.translate} do
      @meeting.member_meetings.find_by(member_id: @invitee.id).get_response_object(@current_occurrence_time).accepted? ? 'display_string.accepted'.translate : 'display_string.declined'.translate
    end

    tag :rsvp_action_capitalized, :description => Proc.new{'email_translations.meeting_rsvp_notification.tags.rsvp_action_capitalized.description'.translate}, :example => Proc.new{'email_translations.meeting_rsvp_notification.tags.rsvp_action_capitalized.example'.translate} do
      @meeting.member_meetings.find_by(member_id: @invitee.id).get_response_object(@current_occurrence_time).accepted? ? 'display_string.Accepted'.translate : 'display_string.Declined'.translate
    end
  end

  self.register!

end
