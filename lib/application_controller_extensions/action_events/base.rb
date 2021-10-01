module ApplicationControllerExtensions::ActionEvents::Base
  include ProxySession
  include RequireAccess
  include LoadRequiredObjects
  include PendingRequestCount

  private  

  def fetch_reset_code
    @password = Password.find_by(reset_code: params[:reset_code])
    @member = @password.try(:member)
    
    handle_reset_code_redirect and return if is_invalid_reset_request?
    @auth_config = get_and_set_current_auth_config
    return unless logged_in_organization?
    handle_loggedin_password_reset
  end

  def handle_set_locale
    if params[:set_locale]
      store_locale_to_member(params[:set_locale]) if wob_member
      store_locale_to_cookie(params.delete(:set_locale))
    end
  end

  # Fix for "Cacheable SSL Page Found" vulnerability - Prevents the caching of SSL Pages.
  def set_cache_header
    response.headers["Cache-Control"] = "no-store, no-cache"
    response.headers["Pragma"] = "no-cache"
  end

  def log_request_details
    if request.session.has_key?(:member_id)
      logger.info "Member ID: #{request.session[:member_id]}"
    else
      logger.info "Member not logged in"
    end
    logger.info "Session ID: #{request.session_options[:id]}"
  end

  # This method will not be called for ajax requests, when used as a before_action
  def audit_activity
    return if skip_audit_activity?
    ActivityLog.send_later(:log_activity, current_user, current_audit_activity)
  end

  # This is to set time zone as the local users time zone
  def set_time_zone
    Time.zone = wob_member.try(:time_zone).presence || TimezoneConstants::DEFAULT_TIMEZONE
  end

  # Will redirect to the default URL on accessing secondary URLs
  def handle_secondary_url
    return if @current_organization.blank? || !request.get?

    current_program_domain = @current_organization.program_domains.find_by(subdomain: current_subdomain, domain: @current_domain)
    return if current_program_domain.blank?

    default_domain = @current_organization.default_program_domain
    if current_program_domain != default_domain
      do_redirect url_for(params.to_unsafe_h.merge(subdomain: default_domain.subdomain, domain: default_domain.domain))
    end
  end

  def set_session_expiry_cookie
    safety_time = AutoLogout::TimeInterval::SAFETY_TIME.minute # safety time should be Slowest page + 2*RTT
    if logged_in_organization?
      expiry_time = @current_organization.security_setting.login_expiry_period.minutes - safety_time
      cookies[AutoLogout::Cookie::SESSION_ACTIVE.to_sym] = {value: (Time.now + expiry_time.seconds).to_i, expires: 5.years.from_now}
    end
  end

  # Filters the users who have their profiles incomplete( i.e they haven't answered the all the required questions aafter they signup)
  # This filter is overridden in sessions_controller and users_controller
  # This method will not be called for ajax requests, when used as a before_action
  def handle_pending_profile_or_unanswered_required_qs
    return if request.xhr? || current_user.blank?

    if current_user.profile_pending?
      flash[:error] = "" if params[:error_raised] == "1" && @current_organization.amazon?
      redirect_to edit_member_path(wob_member, {ei_src: EngagementIndex::Src::EditProfile::PROFILE_PENDING, landing_directly: true, first_visit: true})
    elsif unanswered_mandatory_questions?
      flash[:error] = "" if params[:error_raised] == "1" && @current_organization.amazon?
      @unanswered_mandatory_prof_qs = true
      return if params[:unanswered_mandatory_prof_qs] == "true"
      redirect_to program_root_path({hide_side_bar: true, unanswered_mandatory_prof_qs: true})
    end
  end

  # Filters the users who didn't accept terms and conditions yet
  # This method will not be called for ajax requests, when used as a before_action
  def handle_terms_and_conditions_acceptance
    if !working_on_behalf? && !request.xhr? && logged_in_organization? && !wob_member.terms_and_conditions_accepted?
      redirect_to terms_and_conditions_warning_registrations_path
    end
  end

  # This method will not be called for ajax requests, when used as a before_action
  def check_ip_authentication
    if !request.xhr? && logged_in_organization? && !current_member.is_chronus_admin? && deny_current_ip?
      logout_keeping_session!
      flash[:error] = "flash_message.user_session_flash.ip_authentication_failed_v2".translate(administrator: _admin)
      redirect_to program_view? ? program_root_path : root_organization_path
    end
  end

  def handle_inactive_organization
    if @current_organization && !@current_organization.active?
      redirect_to inactive_organization_path
    end
  end

  def check_browser
    return if request.xhr?

    @invalid_browser = is_unsupported_browser?
    redirect_to upgrade_browser_path and return if @invalid_browser

    # Supported with Warning
    handle_browser_supported_with_warning if browser_supported_with_warning?
  end

  # This is a before_action called in Passwords#reset and Sessions#new
  # Such links are in 'complete_signup_existing_member_notification.rb' emails
  # After signin, the user is taken to the membership form page based on this session data
  def store_signup_roles_in_session
    session[:signup_roles] = { @current_program.root => params[:signup_roles] } if @current_program.present? && params[:signup_roles].present?
  end

  def set_report_category
    @category = params[:category].to_i if params[:report].to_s.to_boolean
  end

  def set_v2_page
    @v2_page = true
  end

  def set_login_mode
    @login_mode = params[:login_mode]
  end

  # Sets the organization_id for the Delayed job
  def set_dj_organization_id
    Delayed::Job.organization_id = @current_organization.id if @current_organization.present?
  end

  def show_pendo_launcher_in_all_devices
    @show_pendo_launcher_in_all_devices = true
  end

  # We are adding a unique token to cookie for A/B tests. We are adding this instead of
  # using the session id/ session active as we want it to persist beyond a session and
  # also be present irrespective of whether the user loggedin
  def set_uniq_cookie_token
    if params[:uniq_token]
      cookies[:uniq_token] = params[:uniq_token]
    else
      cookies[:uniq_token] ||= {value: SecureRandom.uuid, expires: 20.years.from_now}
    end
  end

  def handle_reset_code_redirect(message = nil)
    session[:reset_code] = nil
    flash[:notice] = message if message.present?
    do_redirect root_path
  end

  def is_invalid_reset_request?
    @password.blank? || @member.blank? || (@member.organization_id != @current_organization.id)
  end

  def handle_loggedin_user_reset_code
    if program_view?
      user = @member.user_in_program(current_program)
      message = "flash_message.user_session_flash.not_a_member".translate(program: _program) if user.blank?
    end
    handle_reset_code_redirect(message)
  end

  def skip_audit_activity?
    request.xhr? || current_user.blank? || current_user.is_admin_only? || working_on_behalf? || organization_view?
  end

  def current_audit_activity
    case
    when params[:controller].match(/articles/)
      ActivityLog::Activity::ARTICLE_VISIT
    when (params[:controller].in?([ForumsController.controller_name, TopicsController.controller_name]) && params[:group_id].blank?)
      ActivityLog::Activity::FORUM_VISIT
    when params[:controller].match(/^qa_/)
      ActivityLog::Activity::QA_VISIT
    when params[:controller].match(/resources/)
      ActivityLog::Activity::RESOURCE_VISIT
    else
      ActivityLog::Activity::PROGRAM_VISIT
    end
  end

  def deny_current_ip?
    @current_organization.security_setting.allowed_ips.present? && @current_organization.security_setting.deny_ip?(request.remote_ip)
  end

  def unanswered_mandatory_questions?
    current_user.profile_incomplete_roles.any? && current_user.profile_active? && !working_on_behalf?
  end

  def foreign_domain?
    current_domain != DEFAULT_DOMAIN_NAME
  end

  def handle_loggedin_password_reset
    if @member == wob_member
      handle_loggedin_user_reset_code
    else
      logout_killing_session!
      do_redirect new_user_followup_users_path(reset_code: params[:reset_code])
    end
  end

  def browser_supported_with_warning?
    # Change this method when you want to support a browser with warning.
    false
  end

  def browser_unsupported?
    # As of now, only IE 10 and below are completely unsupported. Add OR clauses when you want to remove support for browsers.
    is_ie_less_than?(11)
  end

  def is_unsupported_browser?
    # Change the BROWSER_WARNING_DATE constant to a date when you want to support a browser with a warning till that date.
    # Also, change browser_supported_with_warning? to return true for if site is accessed from that browser.
    browser_unsupported? || (browser_supported_with_warning? && (Time.now.utc >= BROWSER_WARNING_DATE.utc))
  end

  def handle_browser_supported_with_warning
    if logged_in_at_current_level?
      if current_member.can_show_browser_warning?
        @supported_with_warning_browser = session[:browser_warning_shown] = true
        current_member.update_attributes!(browser_warning_shown_at: Time.now)
      end
    elsif !session[:browser_warning_shown]
      @supported_with_warning_browser = session[:browser_warning_shown] = true
    end
    set_browser_warning_content if @supported_with_warning_browser
  end
end
