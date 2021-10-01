module AuthenticationExtensions
  include CommonControllerUsages

  def openssl_user_attributes
    params[:login_data]
  end

  def saml_response
    params[:SAMLResponse]
  end

  def bbnc_attributes
    bbnc_keys = [:userid, :ts, :sig]
    params.slice(*bbnc_keys)
  end

  def bbnc_attributes_present?
    bbnc_attributes.keys.size == 3
  end

  def cookie_attributes
    { :encrypted_uid => URI.decode(URI.encode_www_form_component(cookies[:enc_constitid])) }
  end

  def cookies_for_sso_present?
    cookies[:enc_constitid].present?
  end

  def soap_token_present?
    params[:nftoken]
  end

  def oauth_flag
    params[OpenAuth::CALLBACK_PARAM]
  end

  def any_sso_attributes_present?
    openssl_user_attributes.present? ||
      saml_response.present? ||
      bbnc_attributes_present? ||
      cookies_for_sso_present? ||
      soap_token_present? ||
      oauth_flag.present?
  end

  def get_and_set_current_auth_config
    login_context = (params[:controller] == "sessions") && params[:action].in?(["new", "create"])
    auth_config = get_current_auth_config(login_context)

    if login_context && auth_config.present?
      set_auth_config_id_in_session(auth_config.id)
    end
    auth_config
  end

  def session_import_data
    return if session[:new_user_import_data].blank?
    session[:new_user_import_data][@current_organization.id]
  end

  def session_import_data_email
    return if session_import_data.blank?
    session_import_data["Member"].present? && session_import_data["Member"]["email"].presence
  end

  def session_import_data_name
    return if session_import_data.blank?
    return if session_import_data["Member"].blank? || session_import_data["Member"]["first_name"].blank? || session_import_data["Member"]["last_name"].blank?

    "#{session_import_data["Member"]["first_name"]} #{session_import_data["Member"]["last_name"]}"
  end

  def initialize_login_sections(auth_configs = nil)
    auth_configs = AuthConfig.classify(auth_configs || @current_organization.auth_configs)
    auth_config_setting = @current_organization.auth_config_setting

    @login_sections = []
    if auth_configs[:custom].present?
      @login_sections << {
        title: auth_config_setting.custom_section_title,
        description: auth_config_setting.custom_section_description,
        auth_configs: auth_configs[:custom]
      }
    end
    if auth_configs[:default].present?
      @login_sections << {
        title: auth_config_setting.default_section_title,
        description: auth_config_setting.default_section_description,
        auth_configs: auth_configs[:default]
      }
    end

    if auth_config_setting.show_default_section_on_top? && (@login_sections.size == 2)
      @login_sections.reverse!
    end
  end

  def clear_auth_config_from_session
    session[:auth_config_id] = nil
  end

  def set_auth_config_id_in_session(auth_config_id)
    session[:auth_config_id] ||= {}
    session[:auth_config_id][@current_organization.id] = auth_config_id
  end

  private

  def get_current_auth_config(login_context)
    auth_configs = @current_organization.auth_configs

    if auth_configs.size == 1
      auth_configs.first
    elsif login_context && (params[:mode] == SessionsController::LoginMode::STRICT)
      nil
    else
      auth_config = auth_configs.find_by(id: params[:auth_config_id]) if params[:auth_config_id].present?
      auth_config ||= auth_configs.find_by(id: params[:auth_config_ids][0]) if params[:auth_config_ids].present? && (params[:auth_config_ids].size == 1)
      auth_config ||= auth_configs.find_by(id: session[:new_custom_auth_user][:auth_config_id]) if new_user_authenticated_externally?
      auth_config ||
        if login_context
          if any_sso_attributes_present?
            get_current_auth_config_based_on_sso_attributes(auth_configs)
          elsif session[:auth_config_id].try(:[], @current_organization.id).present?
            auth_configs.find_by(id: session[:auth_config_id][@current_organization.id])
          end
        end
    end
  end

  def get_current_auth_config_based_on_sso_attributes(auth_configs)
    auth_type = get_auth_type_based_on_sso_attributes
    auth_configs = auth_configs.where(auth_type: auth_type)
    return auth_configs.first if auth_type != AuthConfig::Type::OPEN

    case oauth_flag
    when OpenAuthUtils::Configurations::Linkedin::CALLBACK_PARAM_VALUE
      auth_configs.find(&:linkedin_oauth?)
    when OpenAuthUtils::Configurations::Google::CALLBACK_PARAM_VALUE
      auth_configs.find(&:google_oauth?)
    else
      auth_configs.find(&:custom?)
    end
  end

  def get_auth_type_based_on_sso_attributes
    if oauth_flag.present?
      AuthConfig::Type::OPEN
    elsif !openssl_user_attributes.nil?
      AuthConfig::Type::OPENSSL
    elsif !saml_response.nil?
      AuthConfig::Type::SAML
    elsif bbnc_attributes_present?
      AuthConfig::Type::BBNC
    elsif cookies_for_sso_present?
      AuthConfig::Type::Cookie
    elsif soap_token_present?
      AuthConfig::Type::SOAP
    end
  end
end