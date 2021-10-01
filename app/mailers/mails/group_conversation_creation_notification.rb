class GroupConversationCreationNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid            => "8uwfog08", # rand(36**8).to_s(36)
    :category       => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory    => EmailCustomization::NewCategories::SubCategories::MENTORING_CONNECTIONS_NOTIFICATION,
    :title          => Proc.new { |program| "email_translations.group_conversation_creation_notification.title".translate(program.return_custom_term_hash) },
    :description    => Proc.new { |program| "email_translations.group_conversation_creation_notification.description".translate(program.return_custom_term_hash) },
    :subject        => Proc.new { "email_translations.group_conversation_creation_notification.subject".translate },
    :campaign_id    => CampaignConstants::MENTORING_CONNECTION_MAIL_ID,
    :user_states    => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{ |program| program.ongoing_mentoring_enabled?},
    :campaign_id_2  => CampaignConstants::GROUP_CONVERSATION_CREATION_NOTIFICATION_MAIL_ID,
    :level          => EmailCustomization::Level::PROGRAM,
    :other_registered_tags => [:forum_tags],
    :listing_order  => 9
  }

  def group_conversation_creation_notification(user, topic, options = {})
    @user = user
    @topic = topic
    @forum = @topic.forum
    @options = options
    @group = topic.forum.group
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@user.program)
    set_sender(@options)
    set_username(@user)
    setup_email(@user, from: @topic.user.name, sender_name: (@topic.user.visible_to?(@user) ? initiator_name : nil), message_type: EmailCustomization::MessageType::COMMUNICATION)
    super
  end

  register_tags do
    tag :group_name, :description => Proc.new{"email_translations.group_conversation_creation_notification.tags.group_name.description".translate}, :example => Proc.new{"email_translations.group_conversation_creation_notification.tags.group_name.example".translate} do
      @group.name
    end
  end
  self.register!
end