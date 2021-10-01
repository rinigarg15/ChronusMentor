class ForumTopicNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid            => "wbzd586l", # rand(36**8).to_s(36)
    :category       => EmailCustomization::NewCategories::Type::COMMUNITY,
    :subcategory    => EmailCustomization::NewCategories::SubCategories::FORUMS,
    :title          => Proc.new { |program| "email_translations.forum_topic_notification.title".translate(program.return_custom_term_hash) },
    :description    => Proc.new { |program| "email_translations.forum_topic_notification.description".translate(program.return_custom_term_hash) },
    :subject        => Proc.new { "email_translations.forum_topic_notification.subject".translate },
    :campaign_id    => CampaignConstants::COMMUNITY_MAIL_ID,
    :campaign_id_2  => CampaignConstants::FORUM_NOTIFICATION_MAIL_ID,
    :feature        => FeatureName::FORUMS,
    :user_states    => [User::Status::ACTIVE, User::Status::PENDING],
    :level          => EmailCustomization::Level::PROGRAM,
    :other_registered_tags => [:forum_tags],
    :listing_order  => 1
  }

  def forum_topic_notification(user, topic, options = {})
    @user = user
    @topic = topic
    @forum = @topic.forum
    @options = options
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
  self.register!
end