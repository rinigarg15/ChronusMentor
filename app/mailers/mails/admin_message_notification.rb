class AdminMessageNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => '1x2znf78', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::ADMINISTRATION_EMAILS,
    :title        => Proc.new{|program| "email_translations.admin_message_notification.title_v3".translate(program.return_custom_term_hash.merge({:track_name => program.name}))},
    :description  => Proc.new{|program| "email_translations.admin_message_notification.description".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.admin_message_notification.subject".translate},
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING, User::Status::SUSPENDED],
    :campaign_id  => CampaignConstants::ADMIN_MESSAGE_NOTIFICATION_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :skip_rollout => true,
    :listing_order => 3,
    :notification_setting => UserNotificationSetting::SettingNames::END_USER_COMMUNICATION
  }

  def admin_message_notification(user, admin_message, options)
    @admin_message = admin_message
    @user = user
    @organization = @user.program.organization
    @sender_name = @admin_message.sender_name
    @visible_sender_name = (options[:sender] && options[:sender].is_a?(User) && options[:sender].visible_to?(@user)) ? @sender_name : nil
    message_receiver = @admin_message.message_receivers.first
    @reply_to = [MAILER_ACCOUNT[:reply_to_address].call(message_receiver.api_token, ReplyViaEmail::ADMIN_MESSAGE)]
    attachments[admin_message.attachment_file_name] = admin_message.attachment.content if admin_message.attachment?
    @is_reply_enabled = true
    @options = options
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@admin_message.program)
    set_sender(@options)
    set_username(@user)
    setup_email(@user, :from => @sender_name, :sender_name => (@sender && @sender.is_a?(User)) ? @visible_sender_name : @sender_name , :direct_sender_name => true, message_type: EmailCustomization::MessageType::COMMUNICATION)
    super
  end

  register_tags do
    tag :sender_name, :description => Proc.new{'email_translations.admin_message_notification.tags.sender_name.description'.translate}, :example => Proc.new{"feature.email.tags.mentor_name.example".translate} do
      @admin_message.sender && @admin_message.get_user(@admin_message.sender) ? link_to(@sender_name, member_url(@admin_message.sender, :subdomain => @organization.subdomain)) : @sender_name
    end

    tag :url_message, :description => Proc.new{'email_translations.admin_message_notification.tags.url_message.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      admin_message_url(@admin_message.get_root, :subdomain => @organization.subdomain, :is_inbox => true)
    end

    tag :message_content, :description => Proc.new{'email_translations.admin_message_notification.tags.message_content.description'.translate}, :example => Proc.new{|program| 'email_translations.admin_message_notification.tags.message_content.example_html_v1'.translate(:role => program.get_first_role_term(:articleized_term))} do
      @admin_message.has_rich_text_content? ? @admin_message.formatted_content : wrap_and_break(@admin_message.content)
    end

    tag :reply_button, :description => Proc.new{'email_translations.admin_message_notification.tags.reply_button.description'.translate}, :example => Proc.new{ call_to_action_example('email_translations.admin_message_notification.reply_text'.translate) } do
      call_to_action('email_translations.admin_message_notification.reply_text'.translate, admin_message_url(@admin_message.get_root, :subdomain => @organization.subdomain, :reply => true, :is_inbox => true))
    end

    tag :message_subject, :description => Proc.new{'email_translations.admin_message_notification.tags.message_subject.description'.translate}, :example => Proc.new{|program| 'email_translations.admin_message_notification.tags.message_subject.example_v1'.translate(:role => program.get_first_role_term(:articleized_term_downcase))} do
      @admin_message.auto_email? ? @admin_message.subject.to_s.html_safe : @admin_message.subject
    end
  end

  self.register!

end