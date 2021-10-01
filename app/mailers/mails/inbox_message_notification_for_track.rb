class InboxMessageNotificationForTrack < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          =>  'vbs60t0y', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::COMMUNITY,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::OTHERS,
    :title        => Proc.new{|program| "email_translations.inbox_message_notification_for_track.title".translate({:track_name => program.name})},
    :description  => Proc.new{|program| "email_translations.inbox_message_notification_for_track.description".translate(program.return_custom_term_hash.merge({:track_name => program.name}))},
    :subject      => Proc.new{"email_translations.inbox_message_notification_for_track.subject".translate},
    :campaign_id  => CampaignConstants::INBOX_MESSAGE_NOTIFICATION_FOR_TRACK_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :skip_rollout => true,
    :listing_order => 1
  }

  def inbox_message_notification_for_track(member, program, message, options)
    @member = member
    @program = program
    @message = message
    @options = options
    sender = options[:sender]
    message_receiver = @message.message_receivers.find_by(member_id: member.id)
    @is_reply_enabled = @message.is_a?(AdminMessage) ? message_receiver.present? : true
    if @is_reply_enabled
      @reply_to = @message.is_a?(AdminMessage) ? [MAILER_ACCOUNT[:reply_to_address].call(message_receiver.api_token, ReplyViaEmail::ADMIN_MESSAGE)] : [MAILER_ACCOUNT[:reply_to_address].call(message_receiver.api_token, ReplyViaEmail::MESSAGE)]
    end
    @is_sender_visible_to_receiver = sender.visible_to?(@member) if sender.is_a?(Member)
    @sender_name = @message.is_a?(AdminMessage) ? @message.sender_name : (@is_sender_visible_to_receiver ? sender.name : nil)
    @visible_sender_name = @is_sender_visible_to_receiver ? @sender_name : nil
    attachments[message.attachment_file_name] = message.attachment.content if message.attachment?

    @upcoming_meetings = @is_sender_visible_to_receiver ? Meeting.get_meetings_for_upcoming_widget(program, sender, member) : []

    init_mail
    render_mail
  end

  def self.mailer_locale(member, program, message, options)
    Language.for_member(member, program)
  end

  private

  def init_mail
    set_username(@member)
    set_sender(@options)
    set_program(@program)
    if @message.is_a?(AdminMessage)
      setup_email(@member, :from => @sender_name, :sender_name => @sender ? @visible_sender_name : @sender_name, :direct_sender_name => true, message_type: EmailCustomization::MessageType::COMMUNICATION)
    else
      setup_email(@member, :sender_name => @sender  ? @sender_name : sender_name, :direct_sender_name => true, message_type: EmailCustomization::MessageType::COMMUNICATION)
    end
    super
  end

  register_tags do
    tag :reply_button, :description => Proc.new{'email_translations.inbox_message_notification_for_track.tags.reply_button.description'.translate}, :example => Proc.new{ call_to_action_example('email_translations.inbox_message_notification_for_track.reply_text'.translate) } do
      if @reply_to.present?
        reply_url = @reply_to[0]
        subject = 'feature.email.tags.reply_to_tags.subject'.translate(subject_text: @reply_to_subject)
        call_to_action('email_translations.inbox_message_notification_for_track.reply_text'.translate, reply_url, 'button-large', {mail_to_action: true, subject: subject})
      else
        if @message.is_a?(Message)
          reply_url = message_url(@message.get_root, :subdomain => @organization.subdomain, :root => @program.root, :reply => true, :is_inbox => true)
        elsif @message.is_a?(AdminMessage)
          reply_url = admin_message_url(@message.get_root, :subdomain => @organization.subdomain, :root => @program.root, :reply => true, :is_inbox => true)
        elsif @message.is_group_message?
          group = @message.ref_obj
          reply_url = group_scraps_url(group, :subdomain => @organization.subdomain, :root => group.program.root)
        else
          meeting = @message.ref_obj
          current_occurrence_time = meeting.first_occurrence.to_s
          reply_url = meeting_scraps_url(meeting, :subdomain => @organization.subdomain, :root => meeting.program.root, :current_occurrence_time => current_occurrence_time)
        end
        call_to_action('email_translations.inbox_message_notification_for_track.reply_text'.translate, reply_url)
      end
    end

    tag :reply_button_help_text, description: Proc.new{ 'email_translations.inbox_message_notification_for_track.tags.reply_button_help_text.description'.translate }, example: Proc.new{ 'email_translations.inbox_message_notification_for_track.reply_button_help_text_with_reply_enabled_html'.translate(program: "display_string.Program".translate.downcase, sender_name: "feature.email.tags.mentor_name.example".translate, url_message: "http://www.chronus.com")  } do
      if @reply_to.present?
        'email_translations.inbox_message_notification_for_track.reply_button_help_text_with_reply_enabled_html'.translate(program: @program.term_for(CustomizedTerm::TermType::PROGRAM_TERM).term_downcase, sender_name: sender_name, url_message: url_message)
      else
        'email_translations.inbox_message_notification_for_track.reply_button_help_text_without_reply_enabled_html'.translate(sender_name: sender_name)
      end
    end

    tag :message_subject, description: Proc.new { 'email_translations.inbox_message_notification_for_track.tags.message_subject.description'.translate }, example: Proc.new { 'email_translations.inbox_message_notification_for_track.tags.message_subject.example'.translate } do
      if @message.is_a?(AdminMessage)
        @message.auto_email? ? @message.subject.to_s.html_safe : @message.subject
      else
        @message.subject
      end
    end

    tag :url_message, description: Proc.new { 'feature.email.tags.message_tags.url_message.description'.translate }, example: Proc.new { 'http://www.chronus.com' } do
      AbstractMessagesHelper.get_message_url_for_notification(@message, @organization, ActionMailer::Base.default_url_options)
    end

    tag :sender_name, description: Proc.new { 'email_translations.inbox_message_notification_for_track.tags.sender_name.description'.translate }, example: Proc.new { "feature.email.tags.mentor_name.example".translate } do
      if @message.is_a?(AdminMessage)
        @message.sender.present? ? link_to(@sender_name, member_url(@message.sender, subdomain: @organization.subdomain, root: @program.root)) : @sender_name
      else
        @message.sender.present? ? link_to(@message.sender.name, member_url(@message.sender, subdomain: @organization.subdomain, root: @program.root)) : @message.sender_name
      end
    end

    tag :message_content, description: Proc.new { 'email_translations.inbox_message_notification_for_track.tags.message_content.description'.translate }, example: Proc.new { |program| 'email_translations.inbox_message_notification_for_track.tags.message_content.example'.translate(role: program.get_first_role_term(:articleized_term)) } do
      @message.has_rich_text_content? ? @message.formatted_content : wrap_and_break(@message.content)
    end

    tag :upcoming_meetings_widget, description: Proc.new { |program| 'email_translations.inbox_message_notification_for_track.tags.upcoming_meetings_widget.description'.translate(program.return_custom_term_hash) }, example: Proc.new { |program| 'email_translations.inbox_message_notification_for_track.tags.upcoming_meetings_widget.example_html'.translate(program.return_custom_term_hash) } do
      render(:partial => '/upcoming_meetings_widget').html_safe
    end

    tag :sender_profile_picture, description: Proc.new{'email_translations.inbox_message_notification_for_track.tags.sender_profile_picture.description'.translate}, example: Proc.new{ %Q[<img alt="user name" src="#{UserConstants::DEFAULT_PICTURE[:large]}" style="-ms-interpolation-mode:bicubic;border:0;line-height:100%;text-decoration:none;outline:none;max-width:100% !important;border: none; border-radius: 50%;" title="user name">].try(:html_safe) } do
      if @sender.is_a?(Member)
        user = @sender.user_in_program(@program)
        user_picture_in_email(user, {item_link: member_url(user.member, subdomain: @program.organization.subdomain, root: @program.root, src: :mail), no_name: true, size: :large, use_default_picture_if_absent: true, force_default_picture: @is_sender_visible_to_receiver.blank?}, style: "border: none; border-radius: 50%; margin: 0 auto;", place_image_in_middle: true)
      end
    end
  end
  self.register!
end