class MeetingCreationNotification < ChronusActionMailer::Base
  
  @mailer_attributes = {
    :uid          => 'sc5z16ru', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MEETINGS,
    :title        => Proc.new{|program| "email_translations.meeting_creation_notification.title_v4".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.meeting_creation_notification.description_v3".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.meeting_creation_notification.subject".translate},
    :campaign_id  => CampaignConstants::ENGAGEMENT_MAIL_ID,
    :campaign_id_2  => CampaignConstants::MEETING_CREATION_NOTIFICATION_MAIL_ID,
    :feature      => [FeatureName::CALENDAR, FeatureName::MENTORING_CONNECTION_MEETING],
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :other_registered_tags => [:meeting_tags, :meeting_attachment_tag, :meeting_action_tags, :reply_to_tags, :meeting_rescudule_button_tags],
    :listing_order => 1
  }

  def meeting_creation_notification(user, meeting, ics_attachment, options={})
    @user = user
    @member = user.member
    @meeting_owner = meeting.owner
    @meeting = meeting
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
    set_icalendar_body(@meeting, user: @user)
    @is_reply_enabled = true
    @reply_to = [MAILER_ACCOUNT[:reply_to_address].call(@meeting.get_reply_to_token(@meeting_owner.id, @member.id), ReplyViaEmail::MEETING_CREATED_NOTIFICATION)]
    setup_email(@user, :sender_name => @meeting_owner.visible_to?(@member) ? meeting_owner_name : nil, message_type: EmailCustomization::MessageType::COMMUNICATION)
    super
  end

  register_tags do
    tag :meeting_owner_email, :description => Proc.new{'email_translations.meeting_creation_notification.tags.meeting_owner_email.description'.translate}, :example => Proc.new{'john@gmail.com'} do
      @meeting_owner.email
    end
  end

  self.register!

end
