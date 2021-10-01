module CommonControllerUsages

  def welcome_the_new_user(user, options = {})
    unless options[:skip_login].present?
      logout_killing_session!
      self.current_user = user
    end

    User.send_at(30.minutes.from_now, :send_welcome_email, user.id, (options[:newly_added_roles] || []))
    if options[:not_eligible_to_join_roles].present?
      formatted_role_names = RoleConstants.human_role_string(options[:not_eligible_to_join_roles].map(&:name), program: user.program, no_capitalize: true, articleize: true)
      ineligibility_message = " #{'flash_message.membership.add_role_directly_not_eligible'.translate(role_name: formatted_role_names)}"
      flash_type = :warning
    end

    pending_profile_messsage = user.profile_pending? ? "display_string.and_publish".translate : ""
    flash[flash_type || :notice] = "#{'flash_message.user_flash.invite_signup_done'.translate(program_name: user.program.name, and_publish: pending_profile_messsage)}#{ineligibility_message}"
    do_redirect edit_member_path(user.member, first_visit: user.role_names.join(COMMON_SEPARATOR), ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
  end

  def welcome_the_new_member(member)
    logout_killing_session!
    self.current_member = member

    flash[:notice] = "flash_message.user_flash.signup_done".translate
    do_redirect root_organization_path
  end

  def new_user_authenticated_externally?
    session[:new_custom_auth_user].try(:[], @current_organization.id).present?
  end

  def new_user_external_auth_config
    return unless new_user_authenticated_externally?

    @current_organization.auth_configs.find_by(id: session[:new_custom_auth_user][:auth_config_id])
  end

  def assign_external_login_params(member)
    member.linkedin_access_token = session[:linkedin_access_token] if session[:linkedin_access_token].present?
    handle_linkedin_login_identifier(member) if new_user_external_auth_config.blank? || !new_user_external_auth_config.linkedin_oauth?
    return unless new_user_authenticated_externally?

    external_login_params = session[:new_custom_auth_user]
    member.login_identifiers.build(identifier: external_login_params[@current_organization.id], auth_config_id: new_user_external_auth_config.id)
  end

  def handle_member_who_can_signin_during_signup(member, options = {})
    redirect_path, message_key = get_redirect_path_and_message_key_for_member_who_can_signin_during_signup(member)
    login_link = view_context.link_to("display_string.login".translate, login_path)

    flash[:info] = message_key.translate(program: _program, login_link: login_link) unless options[:hide_flash] || message_key.blank?
    options[:prevent_redirect] ? redirect_path : do_redirect(redirect_path)
  end

  def handle_linkedin_login_identifier(member)
    return if session[:linkedin_login_identifier].blank?

    linkedin_oauth = @current_organization.linkedin_oauth(true)
    return if LoginIdentifier.exists?(auth_config_id: linkedin_oauth.id, identifier: session[:linkedin_login_identifier])
    return if member.login_identifiers.any? { |login_identifier| login_identifier.auth_config_id == linkedin_oauth.id }

    member.login_identifiers.build(auth_config_id: linkedin_oauth.id, identifier: session[:linkedin_login_identifier])
  end

  private

  def get_redirect_path_and_message_key_for_member_who_can_signin_during_signup(member)
    auth_configs = member.auth_configs
    standalone_auth_config = (auth_configs.size == 1) && auth_configs.first

    if standalone_auth_config && standalone_auth_config.remote_login?
      set_auth_config_id_in_session(standalone_auth_config.id)
      [login_path]
    else
      clear_auth_config_from_session
      [login_path(auth_config_ids: auth_configs.pluck(:id)), "flash_message.membership.please_login_to_join"]
    end
  end
end