class CompleteSignupExistingMemberNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'w14hy458', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::APPLY_TO_JOIN,
    :title        => Proc.new{|program| "email_translations.complete_signup_existing_member_notification.title_v3".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.complete_signup_existing_member_notification.description_v4".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.complete_signup_existing_member_notification.subject_v1".translate},
    :program_settings => Proc.new{ |program| program.can_show_apply_to_join_mailer_templates? },
    :campaign_id  => CampaignConstants::MEMBERSHIP_MAIL_ID,
    :user_states  => User::Status.all,
    :always_enabled => true,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 2
  }

  def complete_signup_existing_member_notification(program, member, role_names, password_reset_code, include_signup_params)
    @member = member
    @program = program
    @role_names = role_names
    @password_reset_code = password_reset_code
    @include_signup_params = include_signup_params

    mail_locale = Language.for_member(member, program)
    GlobalizationUtils.run_in_locale(mail_locale) do
      init_mail
      render_mail
    end
  end

  private

  def init_mail
    set_program(@program)
    set_username(@member)
    setup_email(@member, { from: :admin } )
    super
  end

  register_tags do
    tag :user_state_content, description: Proc.new { "email_translations.complete_signup_existing_member_notification.tags.user_state_content.description".translate }, example: Proc.new { "email_translations.complete_signup_existing_member_notification.tags.user_state_content.example_v1".translate } do
      link_to_program = link_to("feature.membership_request.content.registration_mail.visit_program".translate(program: customized_subprogram_term), login_url(subdomain: @program.organization.subdomain, root: @program.root))
      "feature.membership_request.content.registration_mail.non_draft_user_html".translate(program_name: @program.name, link_to_program: link_to_program)
    end

    tag :roles_applied_for, description: Proc.new { "email_translations.complete_signup_existing_member_notification.tags.roles_applied_for.description".translate }, example: Proc.new { |program| program.get_first_role_term(:articleized_term_downcase) } do
      RoleConstants.human_role_string(@role_names, program: @program, no_capitalize: true, articleize: true)
    end

    tag :url_contact_admin, description: Proc.new { "email_translations.complete_signup_existing_member_notification.tags.url_contact_admin.description".translate }, example: Proc.new { "http://www.chronus.com" } do
      get_contact_admin_path(@program, { only_url: true, url_params: { subdomain: @program.organization.subdomain, root: @program.root } } )
    end

    tag :sign_in_program_button, description: Proc.new{'email_translations.complete_signup_existing_member_notification.tags.sign_in_program_button.description'.translate}, :example => Proc.new{ call_to_action_example("email_translations.complete_signup_existing_member_notification.tags.sign_in_program_button.login_to_continue".translate) } do
      url_params = { subdomain: @program.organization.subdomain, root: @program.root }
      url_params.merge!(signup_roles: @role_names) if @include_signup_params
      call_to_action("email_translations.complete_signup_existing_member_notification.tags.sign_in_program_button.login_to_continue".translate, login_url(url_params))
    end

    tag :url_reset_password, description: Proc.new { "email_translations.complete_signup_existing_member_notification.tags.url_reset_password.description".translate }, example: Proc.new { "http://www.chronus.com" } do
      url_params = { subdomain: @program.organization.subdomain, root: @program.root, reset_code: @password_reset_code }
      url_params.merge!(signup_roles: @role_names) if @include_signup_params
      change_password_url(url_params)
    end
  end
  self.register!
end