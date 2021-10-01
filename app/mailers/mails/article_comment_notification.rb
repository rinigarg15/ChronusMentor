class ArticleCommentNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'ylhlo7vh', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::COMMUNITY,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::ARTICLES,
    :title        => Proc.new{|program| "email_translations.article_comment_notification.title_v3".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.article_comment_notification.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.article_comment_notification.subject_v1".translate},
    :campaign_id  => CampaignConstants::COMMUNITY_MAIL_ID,
    :campaign_id_2  => CampaignConstants::ARTICLE_COMMENT_NOTIFICATION_MAIL_ID,
    :feature      => FeatureName::ARTICLES,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 2
  }

  def article_comment_notification(user, comment, options = {})
    @article = comment.article
    @comment = comment
    @user = user
    @commenter = @comment.user
    @options = options
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@user.program)
    set_sender(@options)
    set_username(@user)
    setup_email(@user, :sender_name => @commenter.visible_to?(@user) ? article_commenter_name : nil, message_type: EmailCustomization::MessageType::COMMUNICATION)
    super
    set_layout_options(:show_change_notif_link => true)
  end

  register_tags do
    tag :article_commenter_name, :description => Proc.new{'email_translations.article_comment_notification.tags.article_commenter_name.description'.translate}, :example => Proc.new{'John Doe'} do
      @commenter.name
    end

    tag :url_article_commenter, :description => Proc.new{'email_translations.article_comment_notification.tags.url_article_commenter.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      member_url(@comment.user.member, :subdomain => @organization.subdomain)
    end

    tag :article_title, :description => Proc.new{'email_translations.article_comment_notification.tags.article_title.description'.translate}, :example => Proc.new{'email_translations.article_comment_notification.tags.article_title.example'.translate} do
      @article.title
    end

    tag :url_comment, :description => Proc.new{'email_translations.article_comment_notification.tags.url_comment.description'.translate}, :example => Proc.new{'http://www.chronus.com'}  do
      article_url(@article, :anchor => "comment_#{@comment.id}", :subdomain => @organization.subdomain)
    end

    tag :url_article, :description => Proc.new{'email_translations.article_comment_notification.tags.url_article.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      article_url(@article, :subdomain => @organization.subdomain)
    end

    tag :read_article_button, :description => Proc.new{'email_translations.article_comment_notification.tags.read_article_button.description'.translate}, :example => Proc.new{ call_to_action_example('email_translations.article_comment_notification.read_article'.translate) } do
      call_to_action('email_translations.article_comment_notification.read_article'.translate, article_url(@article, :anchor => "comment_#{@comment.id}", :subdomain => @organization.subdomain))
    end
  end

  self.register!

end
