class ContentModerationUserNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => '5ycj4x60', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::COMMUNITY,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::FORUMS,
    :title        => Proc.new { |program| "email_translations.content_moderation_user_notification.title_v2".translate(program.return_custom_term_hash) },
    :description  => Proc.new { |program| "email_translations.content_moderation_user_notification.description_v3".translate(program.return_custom_term_hash) },
    :subject      => Proc.new { "email_translations.content_moderation_user_notification.subject_v2".translate },
    :feature      => FeatureName::MODERATE_FORUMS,
    :program_settings => Proc.new{ |program| program.forums_enabled? },
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :campaign_id  => CampaignConstants::CONTENT_MODERATION_USER_NOTIFICATION_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 4
  }

  def content_moderation_user_notification(user, post, reason)
    @post = post
    @topic = @post.topic
    @user = user
    @program = post.program
    @reason = reason
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@program)
    set_username(@user, :name_only => true)
    setup_email(@user)
    super
    set_layout_options(:is_from_app => true)
  end

  register_tags do
    tag :post_content, description: Proc.new{'email_translations.content_moderation_user_notification.tags.post_content.description'.translate}, example: Proc.new{'email_translations.content_moderation_user_notification.tags.post_content.example'.translate} do
      h(@post.body)
    end

    tag :reason, description: Proc.new{'email_translations.content_moderation_user_notification.tags.reason.description'.translate}, example: Proc.new{'email_translations.content_moderation_user_notification.tags.reason.example'.translate} do
      @reason
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.content_moderation_user_notification.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@user.program, url_params: { subdomain: @organization.subdomain, root: @user.program.root }, only_url: true)
    end
  end
  self.register!
end