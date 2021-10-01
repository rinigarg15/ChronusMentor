class SessionsController < ApplicationController
  include ApplicationHelper
  include OpenAuthUtils::Extensions
  include Experiments::MobileAppLoginWorkflow::FinishMobileAppExperiment

  module LoginMode
    STRICT = "strict"
    SIGNUP = "signup"
  end

  skip_before_action :verify_authenticity_token, only: :create
  skip_before_action :set_time_zone, :configure_program_tabs, :configure_mobile_tabs, :check_feature_access, :check_browser, only: [:create, :destroy, :refresh, :saml_slo]
  skip_before_action :handle_terms_and_conditions_acceptance, only: [:new, :create, :destroy, :saml_slo]
  skip_before_action :login_required_in_program, :require_program, :back_mark_pages, :handle_pending_profile_or_unanswered_required_qs

  before_action :login_required_in_organization, only: [:refresh, :zendesk, :register_device_token]
  before_action :fetch_auth_config, only: [:new, :create]
  before_action :store_signup_roles_in_session, only: :new
  before_action :handle_strict_mode, only: :new
  before_action :handle_invalid_login_cases, only: :new

  skip_all_action_callbacks only: [:oauth_callback]

  allow exec: :check_admin_member_or_user, only: [:zendesk]

  def new
    initiate_or_complete_authentication if @auth_config.present?
    return if performed?

    prepare_login_page
  end

  def create
    if @auth_config.saml_auth?
      complete_authentication(saml_response)
    else
      complete_authentication([params[:email], params[:password]], false)
    end
  end

  def show
    redirect_to new_session_path
  end

  def destroy
    logout_all_sessions unless perform_slo
    return if performed?
    perform_logout_redirect
  end

  def saml_slo
    handle_saml_slo
  end

  def refresh
    head :ok
  end

  def zendesk
    jwt_payload = JWT.encode(generate_zendesk_payload_data, APP_CONFIG[:zendesk_shared_secret].to_s)
    redirect_url = "#{APP_CONFIG[:zendesk_jwt_url]}?jwt=#{jwt_payload}"
    redirect_url += "&return_to=#{params[:return_to]}" if params[:return_to].present?
    redirect_to redirect_url
  end

  # This action refreshes device token from IOS app, as APN can change device token for any device-app combination
  # This will happen once a day for perf reasons and will be available in session[:mobile_device][:token]
  def register_device_token
    if params[:device_token].present?
      current_member.set_mobile_access_tokens_v2!(params[:device_token], cookies.signed[MobileV2Constants::MOBILE_V2_AUTH_TOKEN], mobile_platform)
    end
    session[:mobile_device] = { token: params[:device_token], refreshed_at: DateTime.now.utc }
    head :ok
  end

  # This action is only for redirecting based on mobile/web app
  def oauth_callback
    parent_session, organization = fetch_parent_session_and_organization_from_oauth_state

    if organization.present?
      oauth_callback_params = parent_session.data["oauth_callback_params"]
      redirect_url = get_redirect_url_from_oauth_callback(organization, oauth_callback_params)

      if oauth_callback_params[:browsertab]
        @redirect_url = "chronustd://#{redirect_url}"
        render layout: false
      else
        set_cjs_close_iab_refresh
        do_redirect(redirect_url)
      end
    else
      head :ok
    end
  end

  private

  def fetch_auth_config
    @chronussupport = (params[:chronussupport] == "true")

    @auth_config = @current_organization.chronussupport_auth_config(session[:chronussupport_step1_complete]) if @chronussupport
    @auth_config ||= get_and_set_current_auth_config
  end

  def handle_strict_mode
    # when mode is strict, user wants ONLY to login
    # so resetting sign-up related session variables
    if params[:mode] == LoginMode::STRICT
      session[:invite_code] = nil
      session[:reset_code] = nil
      session[:signup_code] = nil
      session[:signup_roles] = nil
      session[:login_mode] = LoginMode::STRICT
    elsif params[:auth_config_id].blank? && !any_sso_attributes_present?
      session[:login_mode] = nil
    end
  end

  def check_admin_member_or_user
    wob_member.admin? || current_user.try(&:is_admin?)
  end

  def initiate_or_complete_authentication
    case @auth_config.auth_type
    when AuthConfig::Type::CHRONUS
      chronus_auth_authentication
    when AuthConfig::Type::LDAP
      @login = params[:email]
    when AuthConfig::Type::OPENSSL
      url_based_authentication
    when AuthConfig::Type::SAML
      initialize_saml_authentication
    when AuthConfig::Type::BBNC
      bbnc_authentication
    when AuthConfig::Type::Cookie
      cookie_authentication
    when AuthConfig::Type::SOAP
      if @auth_config.token_based_soap_auth?
        token_based_soap_authentication
      else
        @login = params[:email]
      end
    when AuthConfig::Type::OPEN
      open_authentication
    end
  end

  def handle_invalid_login_cases
    # new action is accessible only when
    # - unloggedin users click on 'Login'
    # - loggedin users click on 'Link to Login' from 'Account Settings' page
    is_from_account_settings = @auth_config.try(:non_indigenous?) && logged_in_organization?
    is_from_account_settings &&= !LoginIdentifier.exists?(member_id: wob_member.id, auth_config_id: @auth_config.id)

    if new_user_authenticated_externally? || (logged_in_organization? && !is_from_account_settings)
      set_cjs_close_iab_refresh
      do_redirect root_path
    end
  end

  def prepare_login_page
    @login_active = true
    @security_setting = @current_organization.security_setting

    if logged_in_organization?
      auth_configs = [@auth_config]
    else
      auth_configs = @current_organization.auth_configs
      auth_configs = auth_configs.where(id: params[:auth_config_ids]) if params[:auth_config_ids].present?
    end
    initialize_login_sections(auth_configs)
  end

  def complete_authentication(attrs, copy_current_program_from_session = true, nftoken_not_set = true)
    attrs = [attrs] unless attrs.is_a?(Array)
    auth_obj = ProgramSpecificAuth.authenticate(@auth_config, *attrs)
    set_cjs_close_iab_refresh
    session[:closed_circles_in_publish_circle_widget_ids] = []
    logger.info "*** #{auth_obj.auth_config.auth_type} response params status: #{auth_obj.status}, uid: #{auth_obj.uid}, login_attempts_count: #{auth_obj.member.try(:failed_login_attempts)}, account_locked_at: '#{auth_obj.member.try(:account_locked_at)}' ***"

    if @auth_config.token_based_soap_auth? && auth_obj.uid.present? && nftoken_not_set
      do_redirect "#{@auth_config.get_options['set_token_url']}&nftoken=#{auth_obj.nftoken}&nfredirect=#{new_session_url}"
    else
      session[:nftoken] = params[:nftoken] if @auth_config.token_based_soap_auth? && params[:nftoken].present?
      add_session_variables_for_saml_slo(auth_obj) if @auth_config.saml_auth? && auth_obj.slo_enabled

      if copy_current_program_from_session
        @current_root ||= session[:prog_root]
        load_current_program
        session[:prog_root] = nil
      end

      logged_in_organization? ? handle_link_to_login(auth_obj) : logout_and_authenticate(auth_obj)
    end
  end

  def perform_slo
    if session[:nftoken].present?
      auth_config = @current_organization.auth_configs.find(&:token_based_soap_auth?)
      SOAPAuth.logout(auth_config.get_options, "nftoken" => session[:nftoken]) if auth_config.present?
    elsif session[:slo_enabled]
      return handle_saml_slo
    elsif cookies[:enc_constitid].present?
      auth_config = @current_organization.auth_configs.find_by(auth_type: AuthConfig::Type::Cookie)
      redirect_to auth_config.get_options[:logout_url] if auth_config.present?
    end
    return nil
  end

  def perform_logout_redirect
    redirect_path =
      if params[:goto] == "login" # 403.html.erb
        login_path(src: "excp")
      elsif Rails.env.demo? # Sales team requirement
        login_path(mode: LoginMode::STRICT)
      else
        @current_organization.logout_path.presence || root_path
      end
    redirect_to redirect_path
  end

  def logout_all_sessions(session_kill_options = {})
    if is_mobile_app?
      MobileDevice.remove_device(cookies, mobile_platform)
      session[:mobile_device] = nil
    end

    if session_kill_options.present?
      logout_killing_session!(session_kill_options[:preserve_session_values], session_kill_options.pick(:dont_preserve_values_for_saml_slo))
    else
      logout_killing_session!
    end
    clear_cookies
  end

  def handle_saml_slo
    # TODO: handle non-ssl case
    return unless @current_organization.has_saml_auth?

    auth_config = @current_organization.saml_auth
    saml_response.present? ? complete_saml_slo(auth_config) : initialize_saml_slo(auth_config)
    return true
  end

  def generate_zendesk_payload_data
    time_now = Time.now.to_i
    payload_data = {
      iat: time_now,
      jti: "#{time_now}/#{rand(36**64).to_s(36)}", # Unique token_id to prevent replaying
      name: current_member.name(name_only: true),
      email: current_member.email,
      tags: @current_organization.name.tr(" ", "_"),
    }
    payload_data[:organization] = @current_organization.account_name if @current_organization.account_name.present?
    payload_data
  end

  def fetch_parent_session_and_organization_from_oauth_state
    return if params[:state].blank?

    unescaped_status = CGI.unescape(params[:state])
    parent_session_id = Base64.urlsafe_decode64(unescaped_status)
    parent_session = ActiveRecord::SessionStore::Session.find_by(session_id: parent_session_id)
    return if parent_session.blank?

    [parent_session, Organization.find_by(id: parent_session.data["home_organization_id"])]
  end

  def set_cjs_close_iab_refresh
    @cjs_close_iab_refresh = 1 if is_mobile_app?
  end

  def chronus_auth_authentication
    if params[:token_code].present? && is_mobile_app?
      #if the login is from email with the link embedded with token
      login_token_based_authentication
    else
      @login = session[:email]
    end
  end

  def url_based_authentication
    if openssl_user_attributes.nil?
      perform_external_redirect(@auth_config.remote_login_url)
    else
      complete_authentication(openssl_user_attributes)
    end
  end

  def initialize_saml_authentication
    saml_settings = @auth_config.saml_settings(session_url(organization_level: true))
    saml_request = Onelogin::Saml::AuthRequest.create(saml_settings)
    perform_external_redirect(saml_request)
  end

  def bbnc_authentication
    return complete_authentication(bbnc_attributes) if bbnc_attributes_present?
    redirect_url = new_session_url(auth_config_id: @auth_config.id)
    bbnc_url = @auth_config.remote_login_url
    bbnc_url << "&redirect=" << redirect_url
    perform_external_redirect(bbnc_url)
  end

  def cookie_authentication
    if cookies_for_sso_present?
      logger.info "********* Cookies #{cookie_attributes} *********"
      complete_authentication(cookie_attributes)
    else
      perform_external_redirect(@auth_config.get_options[:login_url])
    end
  end

  def login_token_based_authentication
    complete_authentication([params[:token_code], {token_login: true}])
  end

  def token_based_soap_authentication
    config = @auth_config.get_options

    if params[:nftoken].present?
      if params[:nftoken] != config["empty_guid"]
        output = SOAPAuth.validate(config, "nftoken" => params[:nftoken])
        uid = output["uid"] if output.present?
        attributes = [:logged_in_already, uid]
        complete_authentication(attributes, false, false)
      end
    else
      perform_external_redirect("#{config['get_token_url']}&nfredirect=#{new_session_url}")
    end
  end

  def open_authentication
    oauth_code = params[:code]

    if params[:error].present?
      auth_obj = ProgramSpecificAuth.new(@auth_config, "")
      auth_obj.status = ProgramSpecificAuth::Status::AUTHENTICATION_FAILURE
      handle_login_failure(auth_obj)
    else
      callback_url = get_open_auth_callback_url
      if oauth_code.present?
        if is_open_auth_state_valid?
          complete_authentication([oauth_code, callback_url])
        else
          OpenAuth.log_or_raise("State Mismatch!")
        end
      else
        perform_external_redirect(open_auth_authorization_redirect_url(callback_url, @auth_config, false, @chronussupport))
      end
    end
  end

  def add_session_variables_for_saml_slo(auth_obj)
    session[:name_qualifier] = auth_obj.name_qualifier
    session[:session_index] = auth_obj.session_index
    session[:slo_enabled] = true
    session[:name_id] = auth_obj.name_id

    logger.debug "Session Data #{session}"
  end

  def handle_link_to_login(auth_obj)
    auth_config = auth_obj.auth_config

    unless auth_config.indigenous?
      if auth_obj.authenticated? || auth_obj.no_user_existence?
        if auth_obj.member.present? && (auth_obj.member != wob_member)
          flash[:error] = "flash_message.user_session_flash.member_mismatch".translate(title: auth_config.title, program: _program)
        else
          perform_member_updates_on_successful_login(wob_member, auth_obj)
          flash[:notice] = "flash_message.user_session_flash.successfully_authenticated".translate
        end
      else
        flash[:error] = auth_obj.error_message.presence || "flash_message.user_session_flash.login_failed".translate
      end
    end
    do_redirect account_settings_path
  end

  def logout_and_authenticate(auth_obj)
    logout_killing_session!(true)
    handle_authentication(auth_obj)
  end

  def clear_cookies
    cookies.delete(CookiesConstants::MENTORING_AREA_VISITED)
    cookies.delete(AutoLogout::Cookie::SESSION_ACTIVE)

    cookies_list = cookies.collect { |cookie| cookie }.flatten
    survey_popup_cookies = cookies_list.select { |key| key =~ Regexp.new(GroupsController::OVERDUE_SURVEY_POPUP_COOKIE_FORMAT) }
    survey_popup_cookies.each { |key| cookies.delete(key) if cookies.key?(key) }
  end

  def complete_saml_slo(auth_config)
    saml_settings = auth_config.saml_settings
    if Onelogin::Saml::LogoutResponse.new(saml_response, saml_settings).success_status?
      set_cjs_close_iab_refresh
      redirect_to @current_organization.logout_path.presence || root_path
      logout_all_sessions(preserve_session_values: false, dont_preserve_values_for_saml_slo: true)
    else
      redirect_to root_path
    end
  end

  def initialize_saml_slo(auth_config)
    redirect_to auth_config.generate_saml_slo_request(SAMLAuth.get_attributes_for_saml_slo(session))
    logout_all_sessions(preserve_session_values: false, dont_preserve_values_for_saml_slo: true)
  end

  def perform_external_redirect(redirect_url)
    return true if handle_unauthorized_xhr(redirect_url)

    prepare_redirect_for_external_authentication
    redirect_to redirect_url
  end

  def handle_unauthorized_xhr(redirect_url)
    return unless request.xhr?

    respond_to do |format|
      format.js do
        render js: "window.location.href = \"#{redirect_url}\";", status: :unauthorized and return true
      end
    end
  end

  def handle_authentication(auth_obj)
    is_chronus_admin = auth_obj.member.try(:is_chronus_admin?)
    if @chronussupport || is_chronus_admin
      handle_chronussupport_auth_validation(auth_obj, is_chronus_admin)
      return if performed?
    end
    auth_obj.authenticated? ? handle_login_success(auth_obj) : handle_login_failure(auth_obj)
  end

  # ChronusAdmin Login: 2 factor authentication - ChronusAuth and Google OAuth
  def handle_chronussupport_auth_validation(auth_obj, is_chronus_admin)
    if auth_obj.auth_config.indigenous?
      handle_indigenous_chronussupport_auth(auth_obj, is_chronus_admin)
      session[:chronussupport_step1_complete] = auth_obj.authenticated? if is_chronus_admin
    else
      handle_non_indigenous_chronussupport_auth(auth_obj)
      session[:chronussupport_step1_complete] = nil
    end
  end

  def handle_login_success(auth_obj)
    self.current_member = auth_obj.member
    if is_mobile_app?
      session[:set_mobile_auth_cookie] = true
      session[:track_mobile_app_login] = true
      finish_mobile_app_login_experiment(cookies[:uniq_token])
    end
    complete_successful_login(auth_obj)
    track_activity_for_ei(EngagementIndex::Activity::LOGIN)
  end

  def handle_login_failure(auth_obj)
    if auth_obj.no_user_existence?
      handle_no_user_existence(auth_obj)
      return
    end

    error_message, redirect_path =
      if auth_obj.member_suspended?
        get_error_message_and_redirect_path_for_member_suspended(auth_obj)
      elsif auth_obj.account_blocked?
        get_error_message_and_redirect_path_for_account_blocked(auth_obj)
      elsif auth_obj.password_expired?
        get_error_message_and_redirect_path_for_password_expired(auth_obj)
      elsif auth_obj.permission_denied?
        get_error_message_and_redirect_path_for_permission_denied(auth_obj)
      elsif auth_obj.invalid_token?
        get_error_message_and_redirect_path_for_invalid_token
      else
        get_error_message_and_redirect_path_for_authentication_failure(auth_obj)
      end

    if redirect_path.blank?
      @error_message = error_message
    else
      flash[:error] = error_message
      do_redirect(redirect_path)
    end
  end

  def complete_successful_login(auth_obj)
    perform_member_updates_on_successful_login(current_member, auth_obj)
    Pendo.reset_pendo_guide_seen_data(current_member, current_user)

    url_params = { lst: ProgramSpecificAuth::StatusParams::AUTHENTICATION_SUCCESS }
    back_mark_options = { additional_params: "lst=#{ProgramSpecificAuth::StatusParams::AUTHENTICATION_SUCCESS}" }
    signup_params = {}
    if session[:signup_code].present?
      program, signup_code_and_roles = get_signup_code_and_roles_in_session
      signup_params = { signup_code: signup_code_and_roles[:code], roles: signup_code_and_roles[:roles], root: program.root } if program.present?
    elsif session[:signup_roles].present?
      program, signup_roles = get_signup_roles_in_session
      signup_params = { roles: signup_roles, root: program.root } if program.present?
    end

    if program_view?
      complete_successful_login_when_program_view(url_params, signup_params, back_mark_options)
    else
      complete_successful_login_when_organization_view(url_params, signup_params, back_mark_options)
    end
  end

  def handle_no_user_existence(auth_obj)
    url_params = { lst: ProgramSpecificAuth::StatusParams::NO_USER_EXISTENCE, org_id: @current_organization.id }
    set_external_user_session(auth_obj)
    program, signup_roles = get_signup_roles_in_session

    if session[:invite_code] && program_view?
      do_redirect new_registration_path(url_params.merge!(invite_code: session[:invite_code]))
    elsif session[:reset_code]
      do_redirect new_user_followup_users_path(url_params.merge!(reset_code: session[:reset_code]))
    elsif signup_roles.present? && program.allow_join_now?
      do_redirect new_membership_request_path(url_params.merge!(root: program.root, roles: signup_roles))
    elsif @current_program.try(:allow_join_now?)
      do_redirect new_membership_request_path(url_params)
    else
      flash[:notice] = "flash_message.user_session_flash.not_a_member".translate(program: _program)
      do_redirect root_path(url_params)
    end
  end

  def get_error_message_and_redirect_path_for_member_suspended(_auth_obj)
    [
      "flash_message.user_session_flash.suspended_member_v2".translate(program: _program, administrator: _admin),
      program_root_path(lst: ProgramSpecificAuth::StatusParams::MEMBER_SUSPENSION, org_id: @current_organization.id)
    ]
  end

  def get_error_message_and_redirect_path_for_account_blocked(auth_obj)
    member = auth_obj.member
    error_message =
      if member.organization.security_setting.reactivation_email_enabled?
        reactivate_link = view_context.link_to('display_string.Click_here'.translate, reactivate_account_path(email: member.email))
        "flash_message.user_session_flash.login_blocked_self_unblock_message_html".translate(click_here: reactivate_link)
      else
        "flash_message.user_session_flash.login_blocked_admin_unblock_message_v1".translate(program: _program, administrator: _admin)
      end
    return [
      error_message,
      program_root_path(lst: ProgramSpecificAuth::StatusParams::ACCOUNT_BLOCKED, org_id: @current_organization.id)
    ]
  end

  def get_error_message_and_redirect_path_for_password_expired(_auth_obj)
    [
      "flash_message.user_session_flash.password_expired".translate,
      program_root_path(lst: ProgramSpecificAuth::StatusParams::PASSWORD_EXPIRED, org_id: @current_organization.id)
    ]
  end

  def get_error_message_and_redirect_path_for_permission_denied(auth_obj)
    [
      (auth_obj.permission_denied_message.presence || "flash_message.user_session_flash.login_failed".translate),
      program_root_path(lst: ProgramSpecificAuth::StatusParams::PERMISSION_DENIED, org_id: @current_organization.id)
    ]
  end

  def get_error_message_and_redirect_path_for_authentication_failure(auth_obj)
    auth_config = auth_obj.auth_config
    error_message = auth_obj.error_message.presence || "flash_message.user_session_flash.login_failed".translate
    logger.warn "Failed login for '#{params[:email]}' from #{request.remote_ip} at #{Time.now.utc} : #{error_message}"

    url_params = {
      lst: ProgramSpecificAuth::StatusParams::AUTHENTICATION_FAILURE,
      org_id: @current_organization.id
    }
    login_params = {}
    login_params[:chronussupport] = true if @chronussupport
    if params[:email].present?
      # Security Fix: Sensitive Data in Query String
      auth_config.indigenous? ? (session[:email] = params[:email]) : (login_params[:email] = params[:email])
    end

    redirect_path =
      unless request.xhr?
        @chronussupport ? new_session_path(url_params.merge!(login_params)) : root_path(url_params)
      end

    return [error_message, redirect_path]
  end

  def get_error_message_and_redirect_path_for_invalid_token
    ["", nil]
  end

  def perform_member_updates_on_successful_login(member, auth_obj)
    return if @chronussupport

    auth_config = auth_obj.auth_config
    if auth_obj.linkedin_access_token.present?
      member.update_attributes(linkedin_access_token: auth_obj.linkedin_access_token)
    end

    if auth_config.indigenous?
      if @current_organization.security_setting.can_show_remember_me?
        handle_remember_cookie!(params[:remember_me] == "1")
      end
    else
      login_identifier = member.login_identifiers.find_or_initialize_by(auth_config_id: auth_config.id)
      login_identifier.identifier = auth_obj.uid
      login_identifier.save!
    end
  end

  def get_signup_code_and_roles_in_session
    program = session[:signup_code].present? ? @current_organization.programs.find_by(root: session[:signup_code].keys.first) : nil
    signup_code_and_roles = program.present? && session[:signup_code][program.root]
    session[:signup_code] = nil
    return program, signup_code_and_roles
  end

  def get_signup_roles_in_session
    program = session[:signup_roles].present? ? @current_organization.programs.find_by(root: session[:signup_roles].keys.first) : nil
    signup_roles = program.present? && session[:signup_roles][program.root]
    session[:signup_roles] = nil
    return program, signup_roles
  end

  def complete_successful_login_when_program_view(url_params, signup_params, back_mark_options)
    self.current_user = get_current_user

    if session[:invite_code]
      do_redirect new_registration_path(url_params.merge!(invite_code: session[:invite_code])) and return
    elsif !current_user
      session[:reset_code] = nil
      handle_no_user_at_program_level(url_params, signup_params)
      return
    end

    # Delta indexing is disabled when *last_seen_at* attribute is updated on every request.
    # The *last_seen_at* attribute needs to be specifically updated here, to do delta indexing,
    # thereby respecting the sort by 'Recently logged in' sort option in users listing.
    update_last_seen_at(true)

    if session[:reset_code]
      session[:reset_code] = nil
      translation_options = {
        program_name: current_user.program.name,
        and_publish: (current_user.profile_pending? ? "display_string.and_publish".translate : "")
      }
      flash[:notice] = "flash_message.user_flash.invite_signup_done".translate(translation_options)
      do_redirect edit_member_path(current_member, url_params.merge!(ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION))
    elsif signup_params.present? && (@current_program.root == signup_params[:root])
      do_redirect new_membership_request_path(url_params.merge!(signup_params))
    elsif session[:login_mode] == LoginMode::STRICT
      do_redirect program_root_path(url_params)
    else
      do_redirect back_url(program_root_path(url_params), back_mark_options)
    end
  end

  def complete_successful_login_when_organization_view(url_params, signup_params, back_mark_options)
    if signup_params.present?
      do_redirect new_membership_request_path(url_params.merge!(signup_params))
    else
      do_redirect back_url(root_organization_path(url_params), back_mark_options)
    end
  end

  def set_external_user_session(auth_obj)
    session[:new_custom_auth_user] = {
      @current_organization.id => auth_obj.uid,
      auth_config_id: auth_obj.auth_config.id,
      is_uid_email: auth_obj.is_uid_email?
    }
    session[:linkedin_access_token] = auth_obj.linkedin_access_token
    session[:new_user_import_data] = { @current_organization.id => auth_obj.import_data } if auth_obj.import_data.present?
  end

  def handle_no_user_at_program_level(url_params, signup_params = {})
    do_redirect new_membership_request_path(url_params.merge!(signup_params)) and return if @current_program.allow_join_now?

    if current_member.user_in_program(current_program).try(:suspended?)
      translation_options = {
        program: _program,
        admins: _admins,
        here: get_contact_admin_path(@current_program, label: "display_string.here".translate)
      }
      flash[:error] = "flash_message.user_session_flash.suspended_user_v3_html".translate(translation_options)
    end

    if session[:login_mode] == LoginMode::STRICT
      do_redirect program_root_path(url_params)
    else
      do_redirect back_url(program_root_path(url_params))
    end
  end

  def handle_indigenous_chronussupport_auth(auth_obj, is_chronus_admin)
    return unless is_chronussupport_auth_email_valid?(auth_obj, params[:email])

    if auth_obj.authenticated?
      do_redirect login_path(chronussupport: true) if is_chronus_admin
    else
      auth_obj.status = ProgramSpecificAuth::Status::AUTHENTICATION_FAILURE
    end
  end

  def handle_non_indigenous_chronussupport_auth(auth_obj)
    return unless is_chronussupport_auth_email_valid?(auth_obj, auth_obj.uid)
    return if auth_obj.authentication_failure?

    chronus_admin = auth_obj.auth_config.organization.chronus_admin
    auth_obj.status =
      if chronus_admin.present?
        auth_obj.member = chronus_admin
        ProgramSpecificAuth::Status::AUTHENTICATION_SUCCESS
      else
        auth_obj.error_message = "flash_message.chronus_session_flash.chronussupport_admin_does_not_exist".translate(email: SUPERADMIN_EMAIL)
        ProgramSpecificAuth::Status::AUTHENTICATION_FAILURE
      end
  end

  def is_chronussupport_auth_email_valid?(auth_obj, email)
    return true if email.to_s.split('@').last == "chronus.com"

    auth_obj.status = ProgramSpecificAuth::Status::AUTHENTICATION_FAILURE
    auth_obj.error_message = "flash_message.chronus_session_flash.chronussupport_login_failure".translate(domain: "chronus.com")
    return false
  end

end