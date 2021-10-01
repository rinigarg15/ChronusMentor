class ForumNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'n81qbsnp', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::COMMUNITY,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::FORUMS,
    :title        => Proc.new { |program| "email_translations.forum_notification.title_v3".translate(program.return_custom_term_hash) },
    :description  => Proc.new { |program| "email_translations.forum_notification.description_v2".translate(program.return_custom_term_hash) },
    :subject      => Proc.new { "email_translations.forum_notification.subject_v2".translate },
    :campaign_id  => CampaignConstants::COMMUNITY_MAIL_ID,
    :campaign_id_2  => CampaignConstants::FORUM_NOTIFICATION_MAIL_ID,
    :feature      => FeatureName::FORUMS,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 2
  }

  def forum_notification(user, post, options = {})
    @user = user
    @post = post
    @topic = @post.topic
    @options = options
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@user.program)
    set_sender(@options)
    set_username(@user)
    setup_email(@user, from: @post.user.name, sender_name: (@post.user.visible_to?(@user) ? posted_member_name : nil), message_type: EmailCustomization::MessageType::COMMUNICATION)
    super
  end

  register_tags do
    tag :posted_member_name, description: Proc.new { "email_translations.forum_notification.tags.posted_member_name.description".translate }, example: Proc.new { "feature.email.tags.mentor_name.example".translate } do
      @post.user.name
    end

    tag :read_post_button, description: Proc.new { "email_translations.forum_notification.tags.read_post_button.description".translate }, example: Proc.new { call_to_action_example("email_translations.forum_notification.read_post".translate) } do
      call_to_action("email_translations.forum_notification.read_post".translate, forum_topic_url(@post.forum, @post.topic, subdomain: @organization.subdomain))
    end

    tag :link_to_posted_member, description: Proc.new { "email_translations.forum_notification.tags.link_to_posted_member.description".translate }, example: Proc.new { "http://www.chronus.com" } do
      user_url(@post.user, subdomain: @organization.subdomain, root: @program.root)
    end
  end
  self.register!
end