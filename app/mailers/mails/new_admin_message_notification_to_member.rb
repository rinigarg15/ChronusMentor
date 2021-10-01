class NewAdminMessageNotificationToMember < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'vunww4r9', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::ADMINISTRATION_EMAILS,
    :title        => Proc.new{|program| "email_translations.new_admin_message_notification_to_member.title_v3".translate(program.return_custom_term_hash.merge({:portal_name => program.name}))},
    :description  => Proc.new{|program| "email_translations.new_admin_message_notification_to_member.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.new_admin_message_notification_to_member.subject".translate},
    :campaign_id  => CampaignConstants::NEW_ADMIN_MESSAGE_NOTIFICATION_TO_MEMBER_MAIL_ID,
    :level        => EmailCustomization::Level::ORGANIZATION,
    :listing_order => 11
  }

  def new_admin_message_notification_to_member(member, admin_message, options = {})
    @admin_message = admin_message
    @member = member
    @organization = @member.organization
    @sender_name = @admin_message.sender_name
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
    set_username(@member)
    set_sender(@options)
    setup_recipient_and_organization(@member, @organization)
    setup_email(@member, :from => @sender_name ,:sender_name => @sender_name,:direct_sender_name => true, message_type: EmailCustomization::MessageType::COMMUNICATION)
    super
    set_layout_options(:show_change_notif_link => false)
  end

  register_tags do
    tag :sender_name, :description => Proc.new{'email_translations.new_admin_message_notification_to_member.tags.sender_name.description'.translate}, :example => Proc.new{'John Doe'} do
      @admin_message.sender ? link_to(@sender_name, member_url(@admin_message.sender, :subdomain => @organization.subdomain)) : @sender_name
    end

    tag :url_message, :description => Proc.new{'email_translations.new_admin_message_notification_to_member.tags.url_message.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      admin_message_url(@admin_message.get_root, :subdomain => @organization.subdomain, :is_inbox => true)
    end

    tag :message_content, :description => Proc.new{'email_translations.new_admin_message_notification_to_member.tags.message_content.description'.translate}, :example => Proc.new{'email_translations.new_admin_message_notification_to_member.tags.message_content.example'.translate} do
	  @admin_message.has_rich_text_content? ? @admin_message.formatted_content : wrap_and_break(@admin_message.content)
    end

    tag :url_reply, :description => Proc.new{'email_translations.new_admin_message_notification_to_member.tags.url_reply.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      admin_message_url(@admin_message.get_root, :subdomain => @organization.subdomain, :reply => true, :is_inbox => true)
    end

    tag :message_subject, :description => Proc.new{'email_translations.new_admin_message_notification_to_member.tags.message_subject.description'.translate}, :example => Proc.new{'email_translations.new_admin_message_notification_to_member.tags.message_subject.example'.translate} do
      @admin_message.auto_email? ? @admin_message.subject.to_s.html_safe : @admin_message.subject
    end

    tag :text_for_inline_reply, :description => Proc.new{'email_translations.new_admin_message_notification_to_member.tags.text_for_inline_reply.description'.translate}, :example => Proc.new{'email_translations.new_admin_message_notification_to_member.tags.text_for_inline_reply.example'.translate} do
      'feature.email.tags.reply_email_user'.translate
    end

    tag :reply_to_message_button, :description => Proc.new{'email_translations.new_admin_message_notification_to_member.tags.reply_to_message_button.description'.translate}, :example => Proc.new{ call_to_action_example('email_translations.new_admin_message_notification_to_member.reply_text'.translate) } do
      call_to_action('email_translations.new_admin_message_notification_to_member.reply_text'.translate, admin_message_url(@admin_message.get_root, :subdomain => @organization.subdomain, :reply => true, :is_inbox => true))
    end
  end

  self.register!

end