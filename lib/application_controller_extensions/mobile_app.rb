module ApplicationControllerExtensions::MobileApp
  private

  def mobile_device?
    browser.device.mobile?
  end

  def is_mobile?
    mobile_device? || is_mobile_app?
  end

  def handle_last_visited_program
    if params[:last_visited_program].to_s.to_boolean && is_mobile_app?
      redirect_url = cookies.signed[MobileV2Constants::CURRENT_PROGRAM_COOKIE]
      redirect_to validate_url(redirect_url) if redirect_url
    end
  end

  def set_current_program_cookie
    return if @current_organization.blank?
    cookies.signed[MobileV2Constants::CURRENT_PROGRAM_COOKIE] = {
      value: program_root_url(subdomain: @current_organization.subdomain, host: @current_organization.domain, protocol: @current_organization.get_protocol,
      root: @current_program.try(:root)), expires: MobileV2Constants::COOKIE_EXPIRY.days.from_now
    }
  end

  def is_mobile_app?
    is_ios_app? || is_android_app?
  end

  def handle_set_mobile_auth_cookie
    return if skip_mobile_auth_cookie?
    @current_member.mobile_devices.new(platform: mobile_platform).set_mobile_auth_cookie(cookies, true)
    session[:set_mobile_auth_cookie] = nil
  end

  def show_mobile_prompt
    unless params[:cjs_skip_mobile_prompt]
      set_previous_url_mobile_prompt
      redirect_to mobile_prompt_pages_url if is_mobile_prompt_required?
    end
  end

  def set_previous_url_mobile_prompt
    session[:return_to_url] = request.original_url if request.get?
  end

  def is_mobile_prompt_required?
    logged_in_at_current_level? && cookies[MobileV2Constants::MOBILE_APP_PROMPT].nil? && mobile_browser? && @current_organization.mobile_view_enabled?
  end

  def skip_mobile_auth_cookie?
    session[:set_mobile_auth_cookie].blank? || secure_domain_access? || !logged_in_organization? || !is_mobile_app?
  end

  def validate_url(redirect_url)
    url = URI.parse(redirect_url)
    program_root = url.path[/#{SubProgram::PROGRAM_PREFIX}([^\/]*)(\/?)/, 1] # we are extracting p1 from /p/p1/ and p1 from /p/p1. Similar code exists in lib/routing_filter/program_prefix.rb.
    program_root_url(host: url.host, protocol: url.scheme, root: program_root)
  end
end
