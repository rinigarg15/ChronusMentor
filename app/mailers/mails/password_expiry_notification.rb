class PasswordExpiryNotification < ChronusActionMailer::Base
  @mailer_attributes = {
    :uid          => 'afev9smf', # rand(36**8).to_s(36)
    :title        => Proc.new{|program| "email_translations.password_expiry_notification.title_v1".translate},
    :description  => Proc.new{|program| "email_translations.password_expiry_notification.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.password_expiry_notification.subject_v1".translate},
    :campaign_id  => CampaignConstants::USER_SETTINGS_ROLES_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{ |program| program.organization.password_auto_expire_enabled? },
    :campaign_id_2  => CampaignConstants::PASSWORD_EXPIRY_NOTIFICATION_MAIL_ID,
    :level        => EmailCustomization::Level::ORGANIZATION,
    :donot_list   => true
  }

  def password_expiry_notification(password, organization)
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
    tag :url_reset_password, :description => Proc.new{'email_translations.password_expiry_notification.tags.url_reset_password.description'.translate}, :example => Proc.new{"http://www.chronus.com"} do
      change_password_url(:subdomain => @organization.subdomain, :reset_code => @password.reset_code, :password_expiry => true)
    end

    tag :reset_password_button, :description => Proc.new{'email_translations.password_expiry_notification.tags.reset_password_button.description'.translate}, :example => Proc.new{ call_to_action_example('email_translations.password_expiry_notification.reset_password'.translate) } do
      call_to_action('email_translations.password_expiry_notification.reset_password'.translate, change_password_url(:subdomain => @organization.subdomain, :reset_code => @password.reset_code, :password_expiry => true))
    end
  end

  self.register!
end