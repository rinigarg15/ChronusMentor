module OpenAuthUtils
  module Extensions
    include DefaultUrlsHelper

    def get_open_auth_callback_url
      url_params = default_url_params
      url_params.merge!(organization_level: true, SID_PARAM_NAME => nil)
      oauth_callback_session_url(url_params)
    end

    def get_redirect_url_from_oauth_callback(organization, oauth_callback_params)
      url_params = params.permit(:state, :code, :error).to_h
      url_params.merge!(host: organization.url)
      url_params.merge!(port: nil) if oauth_callback_params[:browsertab]
      url_params.merge!(oauth_callback_params.except(:browsertab))
      url_for(url_params)
    end

    def open_auth_authorization_redirect_url(callback_url, auth_config, from_importer = false, chronussupport = false)
      set_open_auth_callback_params_in_session(auth_config, from_importer, chronussupport)

      oauth_client = OpenAuth.initialize_client(callback_url, auth_config.get_options)
      oauth_client.auth_code.authorize_url(get_open_auth_state_param)
    end

    def is_open_auth_state_valid?
      params["state"].present? && (session[OpenAuth::STATE_VARIABLE_IN_SESSION] == params["state"])
    end

    def set_open_auth_callback_params_in_session(auth_config, from_importer, chronussupport, options = {})
      oauth_callback_params = get_open_auth_callback_controller_and_action_param(from_importer, options)
      oauth_callback_params[OpenAuth::CALLBACK_PARAM] = options[:oauth_callback_param_value] || (auth_config && auth_config.get_options["callback_param_value"].presence) || true
      oauth_callback_params[:browsertab] = true if get_browsertab_value(auth_config, options)
      oauth_callback_params[:chronussupport] = true if chronussupport

      session[:oauth_callback_params] = oauth_callback_params
    end

    def get_open_auth_state_param
      session[OpenAuth::STATE_VARIABLE_IN_SESSION] = Base64.urlsafe_encode64(session.id.to_s)
      { state: session[OpenAuth::STATE_VARIABLE_IN_SESSION] }
    end

    def prepare_redirect_for_external_authentication(options = {})
      session[:continue_secure_access] = true if secure_domain_access?
      session[:prog_root] = current_root
      session[:organization_wide_calendar] = options[:organization_wide_calendar] if options[:set_organization_wide_calendar]
      session[:o_auth_final_redirect] = options[:o_auth_final_redirect] if options[:o_auth_final_redirect]
    end

    private

    def get_browsertab_value(auth_config, options = {})
      (!options[:mobile_support_disabled]) && is_mobile_app? && use_browsertab?(auth_config, options)
    end

    def use_browsertab?(auth_config, options = {})
      options[:use_browsertab_in_mobile] || use_browsertab_for_auth_config?(auth_config)
    end

    def use_browsertab_for_auth_config?(auth_config)
      auth_config && auth_config.use_browsertab_in_mobile?
    end

    def get_open_auth_callback_controller_and_action_param(from_importer, options = {})
      if options[:source_controller_action]
        options[:source_controller_action]
      elsif from_importer
        { controller: LinkedinImportController.controller_name, action: "callback" }
      else
        { controller: SessionsController.controller_name, action: "new" }
      end
    end
  end
end