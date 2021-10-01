class MobileAppLogin < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'mv17t594', # rand(36**8).to_s(36)
    :title        => Proc.new{|program| "email_translations.mobile_app_login.title".translate(program.return_custom_term_hash)},
    :description  => Proc.new{"email_translations.mobile_app_login.description".translate},
    :subject      => Proc.new{"email_translations.mobile_app_login.subject".translate},
    :campaign_id  => CampaignConstants::MOBILE_APP_LOGIN_MAIL_ID,
    :level        => EmailCustomization::Level::ORGANIZATION,
    :always_enabled => true,
    :donot_list   => true
  }

  def mobile_app_login(member, login_token, uniq_token)
    @member = member
    @organization = member.organization
    @login_token = login_token
    @uniq_token = uniq_token
    init_mail
    render_mail
  end

  private

  def init_mail
    set_username(@member)
    setup_recipient_and_organization(@member, @organization)
    setup_email(@member)
    super
  end

  register_tags do
    tag :mobile_app_login_button, :description => Proc.new{'email_translations.mobile_app_login.tags.mobile_app_login_button.description'.translate(:program => @_program_string)}, :example => Proc.new{ 'email_translations.mobile_app_login.tags.mobile_app_login_button.example'.translate(program: @_program_string) } do
      auth_config_id = @organization.chronus_auth.try(:id)
      recently_visited_program = @member.get_recently_visited_program_from_activity_log
      url_opts = {subdomain: @organization.subdomain, domain: @organization.domain, token_code: @login_token.token_code, auth_config_id: auth_config_id, mobile_app_login: true, uniq_token: @uniq_token, root: recently_visited_program.root}
      render(partial: '/mobile_app_login_button', locals: {url: mobile_prompt_pages_url(url_opts)})
    end

    tag :organization_name, :description => Proc.new{'email_translations.mobile_app_login.tags.organization_name.description'.translate}, :example => Proc.new{ 'email_translations.mobile_app_login.tags.organization_name.example'.translate } do
      @organization.name
    end

    tag :email, :description => Proc.new{'email_translations.mobile_app_login.tags.email.description'.translate}, :example => Proc.new{ 'email_translations.mobile_app_login.tags.email.example'.translate } do
      @member.email
    end
  end

  self.register!

end
