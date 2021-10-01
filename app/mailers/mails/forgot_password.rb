class ForgotPassword < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'ezkgp8mo', # rand(36**8).to_s(36)
    :title        => Proc.new{|program| "email_translations.forgot_password.title".translate},
    :description  => Proc.new{|program| "email_translations.forgot_password.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.forgot_password.subject".translate},
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :campaign_id  => CampaignConstants::FORGOT_PASSWORD_MAIL_ID,
    :level        => EmailCustomization::Level::ORGANIZATION,
    :always_enabled => true,
    :donot_list   => true
  }

  def forgot_password(password, organization)
    @password = password
    @organization = organization
    init_mail
    render_mail
  end

  private

  def init_mail
    member = @password.member
    set_username(member)
    setup_recipient_and_organization(member, @organization)
    setup_email(member)
    super
  end

  register_tags do
    tag :url_reset_password, :description => Proc.new{'email_translations.forgot_password.tags.url_reset_password.description'.translate}, :example => Proc.new{"http://www.chronus.com"} do
      change_password_url(:subdomain => @organization.subdomain, :reset_code => @password.reset_code)
    end

    tag :reset_password_button, :description => Proc.new{'email_translations.forgot_password.tags.reset_password_button.description'.translate}, :example => Proc.new{ call_to_action_example('email_translations.forgot_password.reset_password'.translate) } do
      call_to_action('email_translations.forgot_password.reset_password'.translate, change_password_url(:subdomain => @organization.subdomain, :reset_code => @password.reset_code))
    end
  end

  self.register!

end
