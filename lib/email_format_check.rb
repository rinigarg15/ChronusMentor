module EmailFormatCheck
  def validate_email_format(not_an_admin, email, security_setting)
    if not_an_admin && security_setting.present? && security_setting.email_domain.present?
      unless is_allowed_domain?(email, security_setting)
        errors.add(:email, "flash_message.password_flash.invalid_email_domain".translate(email_domain: security_setting.email_domain.downcase)) 
      end
    end
  end

  def is_allowed_domain?(email, security_setting)
    if security_setting.present? && security_setting.email_domain.present?
      email_domain = security_setting.email_domain.downcase
      domains = email_domain.split(",").map { |domain| domain.strip }
      current_domain = email.split("@").last.downcase
      return domains.include?(current_domain)
    end
    return true
  end
end