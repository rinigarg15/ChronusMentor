class AutoEmailNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => '2xw1lphb', # rand(36**8).to_s(36)
    :title        => Proc.new{"email_translations.auto_email_notification.title_v1".translate},
    :description  => Proc.new{"email_translations.auto_email_notification.description_v1".translate},
    :subject      => Proc.new{"email_translations.auto_email_notification.subject_v1".translate},
    :campaign_id  => CampaignConstants::MESSAGE_MAIL_ID,
    :campaign_id_2  => CampaignConstants::AUTO_EMAIL_NOTIFICATION_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :donot_list   => true
  }

  def auto_email_notification(user, admin_message, options={})
    @user = user
    @sender_name = admin_message.sender_name
    @member = user.member
    @organization = @member.organization
    @program = admin_message.program
    @group = admin_message.group
    message_receiver = admin_message.message_receivers.find_by(member_id: @member.id)
    @admin_message = admin_message
    @is_reply_enabled = true
    @reply_to = [MAILER_ACCOUNT[:reply_to_address].call(message_receiver.api_token, ReplyViaEmail::ADMIN_MESSAGE)]
    attachments[admin_message.attachment_file_name] = admin_message.attachment.content if admin_message.attachment?
    init_mail
    replace_tags(@admin_message)
    render_mail
  end

  private

  def init_mail
    set_username(@member)
    setup_recipient_and_organization(@member, @organization, @program)
    setup_email(@member, :from => @sender_name)
    super
    set_layout_options(:show_change_notif_link => false)
  end

  def replace_tags(admin_message)
    admin_message.update_attributes(content: render(inline: "<%= Mustache.render(content, process_tags({:email_template => content})).html_safe %>", locals: { :content => admin_message.content }))
    admin_message
  end

  register_tags do
    tag :message_content, :description => Proc.new{'email_translations.auto_email_notification.tags.message_content.description'.translate}, eval_tag: true do
      if @admin_message.present?
        @admin_message.auto_email? ? @admin_message.content.to_s.html_safe : @admin_message.content
      else
        'email_translations.auto_email_notification.tags.message_content.example'.translate
      end
    end

    tag :url_reply, :description => Proc.new{'email_translations.auto_email_notification.tags.url_reply.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      admin_message_url(@admin_message.get_root, :subdomain => @organization.subdomain, :reply => true, :is_inbox => true)
    end

    tag :message_subject, :description => Proc.new{'email_translations.auto_email_notification.tags.message_subject.description'.translate}, eval_tag: true do
      if @admin_message.present?
        @admin_message.auto_email? ? @admin_message.subject.to_s.html_safe : @admin_message.subject
      else
        'email_translations.auto_email_notification.tags.message_subject.example'.translate
      end
    end

    tag :mentoring_connection_name, :description => Proc.new{|program| 'email_translations.auto_email_notification.tags.mentoring_connection_name.description_v1'.translate(program.return_custom_term_hash)}, :example => Proc.new{"feature.email.tags.campaign_tags.group_name.example".translate}  do
      @admin_message.group.present? ? @admin_message.group.name : ""
    end

    tag :text_for_inline_reply, :description => Proc.new{'email_translations.auto_email_notification.tags.text_for_inline_reply.description'.translate}, :example => Proc.new{'email_translations.auto_email_notification.tags.text_for_inline_reply.example_v2'.translate} do
      'feature.email.tags.reply_email_user'.translate
    end
  end

  self.register!

end