class ChronusAuth < ModelAuth
  LOGO = "https://#{CHRONUS_MENTOR_ASSETS_BUCKET}.#{GLOBAL_ASSETS_DOMAIN_URL}/global-assets/images/chronus-login.png"

  def self.authenticate?(auth_obj, options = {})
    ActiveRecord::Base.transaction do
      auth_obj.uid = auth_obj.data[0]
      is_token_login = is_login_by_token?(auth_obj.data)
      auth_obj.member = get_member_object(auth_obj, is_token_login)
      member_obj = auth_obj.member

      if member_obj.present?
        organization_obj = member_obj.organization
        if member_obj.login_attempts_exceeded? && !member_obj.can_reactivate_account?
          status = ProgramSpecificAuth::Status::ACCOUNT_BLOCKED
        else
          member_obj.handle_reactivate_account!(false) if member_obj.login_attempts_exceeded? && member_obj.account_locked_at.present? && member_obj.can_reactivate_account?
          auth_status = is_token_login ? true : member_obj.authenticated?(auth_obj.data[1])
          if auth_status
            # On successful login, always reset the login counter
            member_obj.reactivate_account!(false)
            if !is_token_login && organization_obj.password_auto_expire_enabled? && member_obj.password_expired?
              status = ProgramSpecificAuth::Status::PASSWORD_EXPIRED
              member_obj.send_reactivation_email(false)
            end
          else
            member_obj.increment_login_counter!
            if member_obj.login_attempts_exceeded?
              if organization_obj.security_setting.reactivation_email_enabled?
                member_obj.send_reactivation_email
              end
              member_obj.account_lockout!
              status = ProgramSpecificAuth::Status::ACCOUNT_BLOCKED
            else
              status = ProgramSpecificAuth::Status::AUTHENTICATION_FAILURE
            end
          end
        end
      else
        status = is_token_login ? ProgramSpecificAuth::Status::INVALID_TOKEN : ProgramSpecificAuth::Status::AUTHENTICATION_FAILURE
      end
      auth_obj.status = status
      auth_status
    end
  end

  private

  def self.get_member_object(auth_obj, is_token_login)
    if is_token_login
      login_token = LoginToken.find_by(token_code: auth_obj.data[0])
      return if login_token.nil? || login_token.expired?
      login_token.mark_expired
      member_obj = login_token.member
    else
      member_obj = auth_obj.auth_config.organization.members.where(email: auth_obj.data[0]).lock(true).first
    end
    member_obj
  end

  def self.is_login_by_token?(args)
    args[1].is_a?(Hash) && args[1][:token_login]
  end
end