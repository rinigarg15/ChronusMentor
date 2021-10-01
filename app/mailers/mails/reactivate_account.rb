class ReactivateAccount < ChronusActionMailer::Base
  @mailer_attributes = {
    :uid          => 'w45h963e', # rand(36**8).to_s(36)
    :title        => Proc.new{|program| "email_translations.reactivate_account.title_v1".translate},
    :description  => Proc.new{|program| "email_translations.reactivate_account.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.reactivate_account.subject_v1".translate},
    :campaign_id  => CampaignConstants::USER_SETTINGS_ROLES_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{ |program| program.organization.security_setting.reactivation_email_enabled? },
    :campaign_id_2  => CampaignConstants::REACTIVATE_ACCOUNT_MAIL_ID,
    :level        => EmailCustomization::Level::ORGANIZATION,
    :donot_list   => true
  }

  def reactivate_account(password, organization)
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
    tag :url_reactivate_account, :description => Proc.new{'email_translations.reactivate_account.tags.url_reactivate_account.description'.translate}, :example => Proc.new{"http://www.chronus.com"} do
      change_password_url(:subdomain => @organization.subdomain, :reset_code => @password.reset_code, :reactivate_account => true)
    end

    tag :maximum_login_attempts, :description => Proc.new{'email_translations.reactivate_account.tags.maximum_login_attempts.description'.translate}, :example => Proc.new{"5"} do
      @organization.security_setting.maximum_login_attempts
    end

    tag :reactivate_account_button, :description => Proc.new{'email_translations.reactivate_account.tags.reactivate_account_button.description'.translate}, :example => Proc.new{ call_to_action_example('email_translations.reactivate_account.reactivate_account_button_text'.translate) } do
      call_to_action('email_translations.reactivate_account.reactivate_account_button_text'.translate, change_password_url(:subdomain => @organization.subdomain, :reset_code => @password.reset_code, :reactivate_account => true))
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.reactivate_account.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(nil, url_params: { subdomain: @organization.subdomain }, organization: @organization, only_url: true)
    end
  end

  self.register!
end