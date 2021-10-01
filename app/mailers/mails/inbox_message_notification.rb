class InboxMessageNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'f57py6o7', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::COMMUNITY,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::OTHERS,
    :title        => Proc.new{|program| "email_translations.inbox_message_notification.title_v2".translate(program.return_custom_term_hash.merge({:portal_name => program.name}))},
    :description  => Proc.new{|program| "email_translations.inbox_message_notification.description".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.inbox_message_notification.subject".translate},
    :campaign_id  => CampaignConstants::INBOX_MESSAGE_NOTIFICATION_MAIL_ID,
    :level        => EmailCustomization::Level::ORGANIZATION,
    :skip_rollout => true,
    :listing_order => 3
  }

  def inbox_message_notification(member, message, options)
    @message = message
    @member = member
    @organization = @member.organization
    message_receiver = @message.message_receivers.find_by(member_id: @member.id)
    @is_reply_enabled = @message.is_a?(AdminMessage) ? message_receiver.present? : true
    if @is_reply_enabled
      @reply_to = @message.is_a?(AdminMessage) ? [MAILER_ACCOUNT[:reply_to_address].call(message_receiver.api_token, ReplyViaEmail::ADMIN_MESSAGE)] : [MAILER_ACCOUNT[:reply_to_address].call(message_receiver.api_token, ReplyViaEmail::MESSAGE)]
    end
    @sender_user = @message.sender_user
    @sender_name = @message.is_a?(AdminMessage) ? @message.sender_name : options[:sender] && options[:sender].is_a?(Member) && options[:sender].visible_to?(@member) ? options[:sender].name : nil
    @visible_sender_name = options[:sender] && options[:sender].is_a?(Member) && options[:sender].visible_to?(@member) ? @sender_name : nil if @message.is_a?(AdminMessage)
    attachments[message.attachment_file_name] = message.attachment.content if message.attachment?
    @options = options
    init_mail
    render_mail
  end

  private

  def init_mail
    set_username(@member)
    set_sender(@options)
    setup_recipient_and_organization(@member, @organization)
    if @message.is_a?(AdminMessage)
      setup_email(@member, :from => @sender_name, :sender_name => @sender && @sender.is_a?(Member) ? @visible_sender_name : @sender_name, :direct_sender_name => true, message_type: EmailCustomization::MessageType::COMMUNICATION)
    else
      setup_email(@member, :sender_name => @sender && @sender.is_a?(Member) ? @sender_name : sender_name, :direct_sender_name => true, message_type: EmailCustomization::MessageType::COMMUNICATION)
    end
    super
  end

  register_tags do
    tag :url_message, :description => Proc.new{'feature.email.tags.message_tags.url_message.description'.translate}, :example => Proc.new{"http://www.chronus.com"} do
      AbstractMessagesHelper.get_message_url_for_notification(@message, @organization, ActionMailer::Base.default_url_options)
    end

    tag :reply_button, :description => Proc.new{'email_translations.inbox_message_notification.tags.reply_button.description'.translate}, :example => Proc.new{ call_to_action_example('email_translations.inbox_message_notification.reply_text'.translate) } do
      if @reply_to.present?
        reply_url = @reply_to[0]
        subject = 'feature.email.tags.reply_to_tags.subject'.translate(subject_text: @reply_to_subject)
        call_to_action('email_translations.inbox_message_notification.reply_text'.translate, reply_url, 'button-large', {mail_to_action: true, subject: subject})
      else
        reply_url = ""
        if @message.is_a?(Message)
          reply_url = message_url(@message.get_root, :subdomain => @organization.subdomain, :reply => true, :is_inbox => true)
        elsif @message.is_a?(AdminMessage)
          reply_url = admin_message_url(@message.get_root, :subdomain => @organization.subdomain, :reply => true, :is_inbox => true)
        else
          group = @message.ref_obj
          reply_url = group_scraps_url(group, :subdomain => @organization.subdomain, :root => group.program.root)
        end
        call_to_action('email_translations.inbox_message_notification.reply_text'.translate, reply_url)
      end
    end

    tag :reply_button_help_text, description: Proc.new{ 'email_translations.inbox_message_notification.tags.reply_button_help_text.description'.translate }, example: Proc.new{ 'email_translations.inbox_message_notification.reply_button_help_text_with_reply_enabled_html'.translate(organization_name: "display_string.Organization".translate.downcase, sender_name: "feature.email.tags.mentor_name.example".translate, url_message: "http://www.chronus.com") } do
      if @reply_to.present?
        'email_translations.inbox_message_notification.reply_button_help_text_with_reply_enabled_html'.translate(organization_name: @organization.name, sender_name: sender_name, url_message: url_message)
      else
        'email_translations.inbox_message_notification.reply_button_help_text_without_reply_enabled_html'.translate(sender_name: sender_name)
      end
    end

    tag :message_subject, :description => Proc.new{'email_translations.inbox_message_notification.tags.message_subject.description'.translate}, :example => Proc.new{'email_translations.inbox_message_notification.tags.message_subject.example'.translate} do
      if @message.is_a?(AdminMessage)
        @message.auto_email? ? @message.subject.to_s.html_safe : @message.subject
      else
        @message.subject
      end
    end

    tag :sender_name, :description => Proc.new{'email_translations.inbox_message_notification.tags.sender_name.description'.translate}, :example => Proc.new{"feature.email.tags.mentor_name.example".translate} do
      if @message.is_a?(AdminMessage)
        @message.sender.present? && @message.viewer_and_sender_from_same_program?(@member) ? link_to(@sender_name, member_url(@message.sender, subdomain: @organization.subdomain)) : @sender_name
      else
        @message.sender.present? ? link_to(@message.sender.name, member_url(@message.sender, subdomain: @organization.subdomain)) : @message.sender_name
      end
    end

    tag :message_content, :description => Proc.new{'email_translations.inbox_message_notification.tags.message_content.description'.translate}, :example => Proc.new{'email_translations.inbox_message_notification.tags.message_content.example'.translate} do
      @message.has_rich_text_content? ? @message.formatted_content : wrap_and_break(@message.content)
    end

    tag :sender_profile_picture, description: Proc.new{'email_translations.inbox_message_notification.tags.sender_profile_picture.description'.translate}, example: Proc.new{ %Q[<img alt="user name" src="#{UserConstants::DEFAULT_PICTURE[:large]}" style="-ms-interpolation-mode:bicubic;border:0;line-height:100%;text-decoration:none;outline:none;max-width:100% !important;border: none; border-radius: 50%;" title="user name">].try(:html_safe) } do
      if @sender.is_a?(Member)
        member_picture_in_email(@sender, {item_link: member_url(@sender, subdomain: @organization.subdomain, src: :mail), no_name: true, size: :large, use_default_picture_if_absent: true, force_default_picture: !@sender.visible_to?(@member)}, style: "border: none; border-radius: 50%; margin: 0 auto;", place_image_in_middle: true)
      end
    end
  end
  self.register!
end