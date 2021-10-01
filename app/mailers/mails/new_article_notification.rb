class NewArticleNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 's9kiyrsk', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::COMMUNITY,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::ARTICLES,
    :title        => Proc.new{|program| "email_translations.new_article_notification.title_v3".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.new_article_notification.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.new_article_notification.subject_v1".translate},
    :feature      => FeatureName::ARTICLES,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :campaign_id  => CampaignConstants::NEW_ARTICLE_NOTIFICATION_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 1
  }

  def new_article_notification(user, article, options = {})
    @article = article
    @user = user
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@user.program)
    set_username(@user)
    setup_email(@user, :sender_name => @article.author.user_in_program(@user.program).visible_to?(@user) ? author_name : nil)
    super
    set_layout_options(:show_change_notif_link => true)
  end

  register_tags do
   tag :author_name, :description => Proc.new{'email_translations.new_article_notification.tags.author_name.description'.translate}, :example => Proc.new{'feature.email.tags.mentor_name.example'.translate} do
     @article.author.name
   end

   tag :url_author_profile, :description => Proc.new{'email_translations.new_article_notification.tags.url_author_profile.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
     member_url(@article.author, :subdomain => @organization.subdomain)
   end

   tag :article_title, :description => Proc.new{'email_translations.new_article_notification.tags.article_title.description'.translate}, :example => Proc.new{'email_translations.new_article_notification.tags.article_title.example'.translate} do
     @article.title
   end

   tag :url_article, :description => Proc.new{'email_translations.new_article_notification.tags.url_article.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
     article_url(@article, :subdomain => @organization.subdomain)
   end

   tag :view_article_button, :description => Proc.new{'email_translations.new_article_notification.tags.view_article_button.description'.translate}, :example => Proc.new{ |program| call_to_action_example('email_translations.new_article_notification.read_article'.translate(:article_term => program.term_for(CustomizedTerm::TermType::ARTICLE_TERM).term_downcase)) } do
     call_to_action('email_translations.new_article_notification.read_article'.translate(:article_term => @_article_string), article_url(@article, :subdomain => @organization.subdomain))
   end
  end

  self.register!

end
