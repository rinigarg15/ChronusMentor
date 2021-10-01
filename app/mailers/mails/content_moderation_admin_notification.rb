class ContentModerationAdminNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'vki6mc1a', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::COMMUNITY,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::FORUMS,
    :title        => Proc.new { |program| "email_translations.content_moderation_admin_notification.title_v2".translate(program.return_custom_term_hash) },
    :description  => Proc.new { |program| "email_translations.content_moderation_admin_notification.description_v3".translate(program.return_custom_term_hash) },
    :subject      => Proc.new { "email_translations.content_moderation_admin_notification.subject_v2".translate},
    :feature      => FeatureName::MODERATE_FORUMS,
    :program_settings => Proc.new{ |program| program.forums_enabled? },
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :campaign_id  => CampaignConstants::CONTENT_MODERATION_ADMIN_NOTIFICATION_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 3,
    :notification_setting => UserNotificationSetting::SettingNames::PROGRAM_MANAGEMENT
  }

  def content_moderation_admin_notification(admin, post, options={})
    @post = post
    @topic = post.topic
    @admin = admin
    @program = @post.program
    @post_user = @post.user
    @options = options
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@program)
    set_sender(@options)
    set_username(@admin, :name_only => true)
    setup_email(@admin, message_type: EmailCustomization::MessageType::COMMUNICATION)
    super
    set_layout_options(:is_from_app => true)
  end

  register_tags do

    tag :author_name, description: Proc.new{'email_translations.content_moderation_admin_notification.tags.author_name.description'.translate}, example: Proc.new{'Micheal Slark'} do
      @post.user.name
    end

    tag :author_url, description: Proc.new{'email_translations.content_moderation_admin_notification.tags.author_url.description'.translate}, example: Proc.new{'http://www.chronus.com'} do
      user_url(@post_user, subdomain: @organization.subdomain, root: @program.root)
    end

    tag :post_content, description: Proc.new{'email_translations.content_moderation_admin_notification.tags.post_content.description'.translate}, example: Proc.new{'email_translations.content_moderation_admin_notification.tags.post_content.example'.translate} do
      h(@post.body)
    end

    tag :moderation_page_url, description: Proc.new{'email_translations.content_moderation_admin_notification.tags.moderation_page_url.description'.translate}, example: Proc.new{'http://www.chronus.com'} do
       moderatable_posts_url(subdomain: @organization.subdomain, root: @program.root)
    end

    tag :post_url, description: Proc.new{'email_translations.content_moderation_admin_notification.tags.post_url.description'.translate}, example: Proc.new{'http://www.chronus.com'} do
      forum_topic_url(@post.topic.forum, @post.topic, subdomain: @organization.subdomain, root: @program.root)
    end

    tag :review_post_button, description: Proc.new{'email_translations.content_moderation_admin_notification.tags.review_post_button.description'.translate}, example: Proc.new{ call_to_action_example('email_translations.content_moderation_admin_notification.review_post'.translate) } do
      call_to_action('email_translations.content_moderation_admin_notification.review_post'.translate, forum_topic_url(@post.topic.forum, @post.topic, subdomain: @organization.subdomain, root: @program.root))
    end
  end
  self.register!
end