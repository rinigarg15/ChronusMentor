class CompleteSignupNewMemberNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => '4yzp2je0', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::APPLY_TO_JOIN,
    :title        => Proc.new{|program| "email_translations.complete_signup_new_member_notification.title_v3".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.complete_signup_new_member_notification.description_v4".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.complete_signup_new_member_notification.subject_v1".translate},
    :program_settings => Proc.new{ |program| program.can_show_apply_to_join_mailer_templates? },
    :campaign_id  => CampaignConstants::MEMBERSHIP_MAIL_ID,
    :skip_default_salutation => true,
    :always_enabled => true,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 1
  }

  def complete_signup_new_member_notification(program, email, role_names, signup_code, options = {})
    mail_locale = options[:locale] || I18n.default_locale
    GlobalizationUtils.run_in_locale(mail_locale) do
      @program = program
      @email = email
      @signup_code = signup_code
      @role_names = role_names
      init_mail
      render_mail
    end
  end

  private

  def init_mail
    set_program(@program)
    setup_email(nil, { from: :admin, email: @email } )
    super
  end

  register_tags do
    tag :roles_applied_for, description: Proc.new { "email_translations.complete_signup_new_member_notification.tags.roles_applied_for.description".translate }, example: Proc.new { |program| program.get_first_role_term(:articleized_term_downcase) } do
      RoleConstants.human_role_string(@role_names, program: @program, no_capitalize: true, articleize: true)
    end

    tag :url_signup, description: Proc.new { "email_translations.complete_signup_new_member_notification.tags.url_signup.description".translate }, example: Proc.new { "http://www.chronus.com" } do
      new_membership_request_url(subdomain: @program.organization.subdomain, root: @program.root, signup_code: @signup_code, roles: @role_names)
    end

    tag :organization_name, description: Proc.new { "email_translations.complete_signup_new_member_notification.tags.organization_name.description".translate }, example: Proc.new{ "email_translations.complete_signup_new_member_notification.tags.organization_name.example".translate } do
      @organization.name
    end

    tag :sign_up_button, :description => Proc.new{'email_translations.resend_signup_instructions.tags.sign_up_button.description'.translate}, :example => Proc.new{ call_to_action_example('email_translations.resend_signup_instructions.tags.sign_up_button.signup'.translate) } do
      call_to_action("email_translations.resend_signup_instructions.tags.sign_up_button.signup".translate, new_membership_request_url(subdomain: @program.organization.subdomain, root: @program.root, signup_code: @signup_code, roles: @role_names))
    end
  end

  self.register!

end