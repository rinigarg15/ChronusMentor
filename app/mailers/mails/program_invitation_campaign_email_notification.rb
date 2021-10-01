class ProgramInvitationCampaignEmailNotification < CampaignEmailNotification
  @mailer_attributes = {
    :uid          => "z7hcgs54", # rand(36**8).to_s(36)
    :title        => Proc.new{"email_translations.campaign_email_notification.title".translate},
    :subject      => Proc.new{"email_translations.campaign_email_notification.subject".translate},
    :description  => Proc.new{"email_translations.campaign_email_notification.description".translate},
    :always_enabled => true,
    :donot_list   => true,
    :level        => EmailCustomization::Level::PROGRAM
    # Add custom headers here
  }


  def program_invitation_campaign_email_notification(obj, message)
    @invite   = obj
    @message  = message
    set_prefered_locale
    init_mail
    render_mail
  end

  def set_prefered_locale
    @set_locale = I18n.locale
    ActionMailer::Base.default_url_options[:set_locale] = @set_locale
  end

  private

  def set_variables_required_for_mustache_rendering(program_invitation, email_template)
    @invite = program_invitation
    set_prefered_locale
    set_program(@invite.program)
  end

  def options_for_mustache_rendering(email_template)
    tags = ChronusActionMailer::Base.mailer_attributes[:tags]
    return {:additional_tags => tags[:program_invitation_campaign_tags].keys}
  end

  def get_subject_and_content
    {:subject => @message.subject, :content => @message.source}
  end

  def campaign_management_message_info
    {:message_id => @message.id, :message_type => "CampaignManagement::CampaignEmail"}
  end


  def init_mail
    set_program(@invite.program)
    member = @invite.sent_to_member
    set_username(member, :name => @invite.sent_to.split('@').first.capitalize)
    email_options = { sender_name: invitor_name }
    email_options.merge!(email: @invite.sent_to) if member.blank?
    setup_email(member, email_options)
    super
  end

  self.register!
end

