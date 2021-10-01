class NewMessageToOfflineUserNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'fqvq7lyu', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::ADMINISTRATION_EMAILS,
    :title        => Proc.new{|program| "email_translations.new_message_to_offline_user_notification.title_v2".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.new_message_to_offline_user_notification.description_v3".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.new_message_to_offline_user_notification.subject".translate},
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :campaign_id  => CampaignConstants::NEW_MESSAGE_TO_OFFLINE_USER_NOTIFICATION_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 4
  }

  def new_message_to_offline_user_notification(admin_message, options={})
    @admin_message = admin_message
    @receiver_name = @admin_message.offline_receiver.name
    @api_token = @admin_message.offline_receiver.api_token
    @reply_to = [MAILER_ACCOUNT[:reply_to_address].call(@api_token, ReplyViaEmail::ADMIN_MESSAGE)]
    attachments[admin_message.attachment_file_name] = admin_message.attachment.content if admin_message.attachment?
    @is_reply_enabled = true
    @options = options
    init_mail
    render_mail
  end

  private

  def init_mail
    @admin_message.program.is_a?(Program) ? set_program(@admin_message.program) : setup_recipient_and_organization(nil, @admin_message.program)
    set_sender(@options)
    set_username(nil, :name => @receiver_name)
    setup_email(nil, :email => @admin_message.offline_receiver.email, :from => :admin, :sender_name => @admin_message.sender_name, :direct_sender_name => true, message_type: EmailCustomization::MessageType::COMMUNICATION)
    super
    set_layout_options(:show_change_notif_link => false)
  end

  register_tags do
    tag :message_subject, :description => Proc.new{'email_translations.new_message_to_offline_user_notification.tags.message_subject.description'.translate}, :example => Proc.new{'email_translations.new_message_to_offline_user_notification.tags.message_subject.example'.translate} do
      @admin_message.subject
    end

    tag :message_content, :description => Proc.new{'email_translations.new_message_to_offline_user_notification.tags.message_content.description'.translate}, :example => Proc.new{'email_translations.new_message_to_offline_user_notification.tags.message_content.example'.translate} do
      @admin_message.has_rich_text_content? ? @admin_message.formatted_content : wrap_and_break(@admin_message.content)
    end

    tag :url_reply, :description => Proc.new{'email_translations.new_message_to_offline_user_notification.tags.url_reply.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      @admin_message.program.is_a?(Program) ? get_contact_admin_path(@program, url_params: { subdomain: @organization.subdomain, root: @program.root }, only_url: true) : get_contact_admin_path(nil, url_params: { subdomain: @organization.subdomain }, organization: @organization, only_url: true)
    end

    tag :text_for_inline_reply, :description => Proc.new{'email_translations.new_message_to_offline_user_notification.tags.text_for_inline_reply.description'.translate}, :example => Proc.new{'email_translations.new_message_to_offline_user_notification.tags.text_for_inline_reply.example'.translate} do
      'feature.email.tags.reply_email_user'.translate
    end

    tag :reply_button, :description => Proc.new{'email_translations.new_message_to_offline_user_notification.tags.reply_button.description'.translate}, :example => Proc.new{ call_to_action_example("email_translations.new_message_to_offline_user_notification.tags.reply_button.reply".translate) } do
      call_to_action("email_translations.new_message_to_offline_user_notification.tags.reply_button.reply".translate, url_reply)
    end

    tag :sender_name, :description => Proc.new{'feature.email.tags.message_tags.sender_name.description'.translate}, :example => Proc.new{'feature.email.tags.mentor_name.example'.translate} do
      @admin_message.sender.present? ? @admin_message.sender.name : @admin_message.sender_name
    end
  end

  self.register!

end