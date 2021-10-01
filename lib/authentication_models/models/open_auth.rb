class OpenAuth < ModelAuth

  INITIALIZATION_PARAMS = ["client_id", "client_secret", "authorize_url", "token_url", "redirect_uri"]
  STATE_VARIABLE_IN_SESSION = :oauth_state
  CALLBACK_PARAM = :oauth_callback

  def self.initialize_client(callback_url, options)
    initialization_params = options.pick(*INITIALIZATION_PARAMS).merge!("redirect_uri" => callback_url)
    unless self.is_initialization_params_valid?(initialization_params)
      self.log_or_raise("Invalid Initialization Params!")
    end

    client_id = initialization_params.delete("client_id")
    client_secret = initialization_params.delete("client_secret")
    OAuth2::Client.new(client_id, client_secret, initialization_params.symbolize_keys!)
  end

  def self.authenticate?(auth_obj, options)
    begin
      client = self.initialize_client(auth_obj.data[1], options)
      access_token = client.auth_code.get_token(auth_obj.data[0])
      response = self.make_api_call(access_token, options)

      if response.present?
        auth_obj.uid = response["uid"]
        auth_obj.import_data = response["import_data"]
        auth_obj.linkedin_access_token = access_token.token if auth_obj.auth_config.linkedin_oauth?
        return true
      end
    rescue OAuth2::Error => e
      Airbrake.notify(e)
    rescue => e
      Airbrake.notify(e)
    end
    return false
  end

  def self.log_or_raise(message, should_raise = true)
    message = "OpenAuth Error: #{message}"

    if should_raise
      raise message
    elsif defined?(Rails)
      Rails.logger.info(message)
    end
  end

  def self.is_initialization_params_valid?(initialization_params)
    initial_inject_value = initialization_params.try(:is_a?, Hash)
    return INITIALIZATION_PARAMS.inject(initial_inject_value) do |is_valid, param_name|
      is_valid && initialization_params[param_name].present?
    end
  end

  def self.make_api_call(access_token, options)
    response = access_token.get(options["api_endpoint"])

    if response.status == HttpConstants::SUCCESS
      if response.content_type == "application/json"
        return options["response_template_proc"].call(JSON.parse(response.body))
      else
        self.log_or_raise("Unsupported Content Type #{response.content_type}!")
      end
    else
      self.log_or_raise("Response Body - #{response.body}", false)
      self.log_or_raise("Invalid Response #{response.status}!")
    end
  end
end