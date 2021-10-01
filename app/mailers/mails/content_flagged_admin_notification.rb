class ContentFlaggedAdminNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'zna7njb', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::COMMUNITY,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::OTHERS,
    :title        => Proc.new{|program| "email_translations.content_flagged_admin_notification.title_v2".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.content_flagged_admin_notification.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.content_flagged_admin_notification.subject".translate},
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :feature      => FeatureName::FLAGGING,
    :program_settings => Proc.new{ |program| program.articles_enabled? || program.qa_enabled? || program.forums_enabled? },
    :campaign_id  => CampaignConstants::CONTENT_FLAGGED_ADMIN_NOTIFICATION_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 2,
    :notification_setting => UserNotificationSetting::SettingNames::PROGRAM_MANAGEMENT
  }

  def content_flagged_admin_notification(admin, flag, options={})
    @flag = flag
    @admin = admin
    @program = flag.program
    @options = options
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@program)
    set_sender(@options)
    set_username(@admin, :name_only => true)
    setup_email(@admin, :sender_name => @flag.user.visible_to?(@admin) ? flagger_name : nil, message_type: EmailCustomization::MessageType::COMMUNICATION)
    super
    set_layout_options(:is_from_app => true)
  end

  register_tags do

    tag :content_type, description: Proc.new{'email_translations.content_flagged_admin_notification.tags.content_type.description'.translate}, example: Proc.new{'email_translations.content_flagged_admin_notification.tags.content_type.example'.translate} do
      @flag.content_type_name.downcase
    end

    tag :flagger_url, description: Proc.new{'email_translations.content_flagged_admin_notification.tags.flagger_url.description'.translate}, example: Proc.new{'http://www.chronus.com'} do
      user_url(@flag.user, subdomain: @organization.subdomain, root: @program.root)
    end

    tag :flagger_name, description: Proc.new{'email_translations.content_flagged_admin_notification.tags.flagger_name.description'.translate}, example: Proc.new{'Micheal Slark'} do
      @flag.user.name
    end

    tag :content_preview, description: Proc.new{'email_translations.content_flagged_admin_notification.tags.content_preview.description'.translate}, example: Proc.new{'email_translations.content_flagged_admin_notification.tags.content_type.description'.translate} do
      content = @flag.content
      case content.class.to_s
      when 'Post'
        return truncate(content.body, length:60, omission: '...')
      when 'Article'
        return truncate(content.article_content.title, length:60, omission: '..')
      when 'Comment'
        return truncate(content.body, length:60, omission: '..')
      when 'QaQuestion'
        return truncate(content.summary, length:60, omission: '..')
      when 'QaAnswer'
        return truncate(content.content, length:60, omission: '..')
      when 'NilClass'
        return 'email_translations.content_flagged_admin_notification.tags.content_preview.nil_content'.translate
      end
    end

    tag :flags_page_url, description: Proc.new{'email_translations.content_flagged_admin_notification.tags.flags_page_url.description'.translate}, example: Proc.new{'http://www.chronus.com'} do
      flags_url(tab: Flag::Tabs::UNRESOLVED, subdomain: @organization.subdomain, root: @program.root)
    end

    tag :content_url, description: Proc.new{'email_translations.content_flagged_admin_notification.tags.content_url.description'.translate}, example: Proc.new{'http://www.chronus.com'} do
      content = @flag.content
      case content.class.to_s
      when 'Post'
        return forum_topic_url(content.topic.forum, content.topic, subdomain: @organization.subdomain, root: @program.root)
      when 'Article'
        return article_url(content, subdomain: @organization.subdomain, root: @program.root)
      when 'Comment'
        return article_url(content.article, subdomain: @organization.subdomain, root: @program.root)
      when 'QaQuestion'
        return qa_question_url(content, subdomain: @organization.subdomain, root: @program.root)
      when 'QaAnswer'
        return qa_question_url(content.qa_question, subdomain: @organization.subdomain, root: @program.root)
      when 'NilClass'
        return '#'
      end
    end

    tag :flag_reason, description: Proc.new{'email_translations.content_flagged_admin_notification.tags.flag_reason.description'.translate}, example: Proc.new{'email_translations.content_flagged_admin_notification.tags.flag_reason.example'.translate} do
      @flag.reason
    end

    tag :resolve_button, description: Proc.new{'email_translations.content_flagged_admin_notification.tags.resolve_button.description'.translate}, example: Proc.new{ call_to_action_example('email_translations.content_flagged_admin_notification.resolve_text_html'.translate) } do
      call_to_action('email_translations.content_flagged_admin_notification.resolve_text_html'.translate, flags_url(tab: Flag::Tabs::UNRESOLVED, subdomain: @organization.subdomain, root: @program.root))
    end

  end

  self.register!

end