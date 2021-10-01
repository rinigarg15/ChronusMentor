class CookieAuth < ModelAuth

  #  ac = org.auth_configs.where(type: AuthConfig::Type::Cookie)
  #  ac.organization_id = org.id
  #  ac.title = "SPE"
  #  ac.auth_type = "CookieAuth"
  #  ac.use_email = false
  #  options = {}
  #  options[:login_url] =  "https://qa.spe.org/appssecured/login/servlet/TpSSOServlet?resource=ementor"
  #  options[:logout_url] = "https://qa.spe.org/appssecured/login/servlet/TpSSOServlet?command=logout"
  #  options[:organization] = "spe"
  #  options ["encryption"] = {
  #     "class" => "EncryptionEngine::DES",
  #     "options" => {
  #       "mode" => "DES",
  #       "key" => "SPEIintl",
  #       "iv" => nil
  #     }
  #  }

  def self.authenticate?(auth_obj, options = {})
    if auth_obj.data.present?
      auth_data = auth_obj.data.first
      encryption_options = options["encryption"]["options"]
      cipher = options["encryption"]["class"].constantize.new(encryption_options["mode"], encryption_options["key"], encryption_options["iv"])
      uid = cipher.decrypt(auth_data[:encrypted_uid])
      auth_obj.uid = uid

      if (options[:organization] == "spe") && uid.present?
        member = auth_obj.auth_config.login_identifiers.find_by(identifier: uid).try(:member)
        unless member
          auth_obj.status = ProgramSpecificAuth::Status::AUTHENTICATION_FAILURE
          auth_obj.error_message = "flash_message.membership.login_failed_for_spe_v1".translate
          return false
        end
        auth_obj.member = member
      end
      return true
    end
    return false
  end
end