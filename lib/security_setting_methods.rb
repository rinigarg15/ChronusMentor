module SecuritySettingMethods
  def override_security_attributes!(params, attrs, is_super_console=false)
    unless (params[:login_exp_per_enable] == "1")
      attrs[:security_setting_attributes][:login_expiry_period] = Organization::DISABLE_LOGIN_EXPIRY
    end

    unless params[:account_lockout] == "1"
      attrs[:security_setting_attributes][:maximum_login_attempts] = Organization::DISABLE_MAXIMUM_LOGIN_ATTEMPTS
    end

    unless params[:reactivate_account] == "1"
      attrs[:security_setting_attributes][:auto_reactivate_account] = Organization::DISABLE_AUTO_REACTIVATE_PASSWORD
    end

    if is_super_console && !(params[:auto_password_expiry] == "1")
      attrs[:security_setting_attributes][:password_expiration_frequency] = Organization::DISABLE_PASSWORD_AUTO_EXPIRY
    end

    if is_super_console && !(params[:password_history_limit] == "1")
      attrs[:security_setting_attributes][:password_history_limit] = nil
    end

    allowed_ips = attrs[:security_setting_attributes][:allowed_ips] || []
    unless allowed_ips.empty?
      attrs[:security_setting_attributes][:allowed_ips] = SecuritySettingService.parse_params(allowed_ips)
    end
  end
end