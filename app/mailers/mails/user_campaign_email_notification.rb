class UserCampaignEmailNotification < CampaignEmailNotification
  @mailer_attributes = {
    :uid          => "uf3pz634", # rand(36**8).to_s(36)
    :title        => Proc.new{"email_translations.campaign_email_notification.title".translate},
    :description  => Proc.new{"email_translations.campaign_email_notification.description".translate},
    :level        => EmailCustomization::Level::PROGRAM,
    :user_states  => User::Status.all,
    :donot_list => true
  }

  def user_campaign_email_notification(user, admin_message, options={})
    @user = user
    @admin_message = admin_message
    @member = user.member
    @options = {}

    init_mail
    render_mail
  end

  private

  def set_sender_name
    campaign_message = @admin_message.campaign_message
    sender_name = campaign_message.render_campaign_message_sender(campaign_message.sender_id, @program)
    @options[:sender_name] = sender_name if sender_name != @program.name
  end

  def set_reply_to
    message_receiver = @admin_message.message_receivers.find_by(member_id: @member.id)
    @reply_to = [MAILER_ACCOUNT[:reply_to_address].call(message_receiver.api_token, ReplyViaEmail::ADMIN_MESSAGE)]
    @is_reply_enabled = true
  end

  def campaign_management_message_info
    {:message_id => @admin_message.id, :message_type => "AbstractMessage"}
  end

  def get_subject_and_content
    {:subject => @admin_message.subject, :content => @admin_message.content}
  end

  def options_for_mustache_rendering(email_template)
    tags = ChronusActionMailer::Base.mailer_attributes[:tags]
    return {:additional_tags => tags[:campaign_tags].keys + tags[:meeting_request_campaign_tags].keys + tags[:mentor_request_campaign_tags].keys + tags[:recommended_mentors_tag].keys}
  end

  def set_variables_required_for_mustache_rendering(user, template)
    member = user.member
    program = user.program
    organization = program.organization
    setup_render_params(user, member, program, organization, template)
  end


  def init_mail
    set_program(@admin_message.program)
    set_sender_name
    set_reply_to
    setup_email(@member, @options)
    super
  end
  self.register!
end

