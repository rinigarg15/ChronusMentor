class SOAPAuth < ModelAuth

  def self.setup(wsdl_path)
    @savon_client = Savon.client(
      wsdl: File.join(Rails.root, wsdl_path),
      open_timeout: 10,
      read_timeout: 10
    )
  end

  def self.authenticate?(auth_obj, auth_config_options)
    if auth_obj.data[0] == :logged_in_already
      if self.is_uid_valid?(auth_obj.data[1], auth_config_options)
        auth_obj.uid = auth_obj.data[1]
        if auth_config_options["validate"].present?
          output = self.validate_member(auth_config_options, { 'uid' => auth_obj.uid })
          self.validate_attributes_from_sso(auth_obj, auth_config_options, output.presence || {})
        end
        return true
      else
        return false
      end
    end

    output = self.login(auth_config_options, { "username" => auth_obj.data[0], "password" => auth_obj.data[1] })
    if output.is_a?(Hash) && self.is_uid_valid?(output["uid"], auth_config_options)
      auth_obj.uid = output["uid"]
      auth_obj.nftoken = output["nftoken"] if auth_obj.auth_config.token_based_soap_auth?
      auth_obj.import_data = imported_data(auth_config_options, output) if auth_config_options["import_data"].present?
      return true
    end
    return false
  end

  def self.login(auth_config_options, input_params)
    self.execute_sequence(auth_config_options["login_sequence"], auth_config_options["setup"], input_params)
  end

  def self.validate(auth_config_options, input_params)
    self.execute_sequence(auth_config_options["validate_sequence"], auth_config_options["setup"], input_params)
  end

  def self.validate_member(auth_config_options, input_params)
    self.execute_sequence(auth_config_options["validate_member_sequence"], auth_config_options["setup"], input_params)
  end

  def self.logout(auth_config_options, input_params)
    self.execute_sequence(auth_config_options["logout_sequence"], auth_config_options["setup"], input_params)
  end

  private

  def self.execute_sequence(sequence, setup_options, input_params)
    input_params.merge!(setup_options["base_params"] || {})
    self.setup(setup_options["wsdl_path"])

    output = false
    sequence.each do |operation, template_paths|
      output = self.make_soap_call(operation, template_paths, input_params)
      return output unless output.is_a?(Hash)
      input_params.merge!(output)
    end
    return output
  end

  def self.build_from_template(template_path, params)
    YAML::load(ERB.new(File.read(File.join(Rails.root, template_path))).result(binding))
  end

  def self.make_soap_call(operation, template_paths, input_params)
    begin
      request = self.build_from_template(template_paths["request"], input_params)
      response = @savon_client.call(operation.to_sym, request)
      if response.success? && template_paths["response"].present?
        output_hash = self.build_from_template(template_paths["response"], response.hash)
        return self.validate_output_hash(output_hash)
      end
      return true
    rescue Savon::SOAPFault => e
      Rails.logger.info "SOAPFault: #{e.message}" if defined?(Rails)
    rescue Psych::SyntaxError => e
      Rails.logger.info "SOAPAuth Psych Error Details: Input params: #{input_params}; Operation: #{operation}; Template Paths: #{template_paths}" if defined?(Rails)
      Airbrake.notify(e)
    rescue => e
      Airbrake.notify(e)
    end
    return false
  end

  def self.multi_dimensional_hash_lookup(hash, keys_sequence)
    keys_sequence.inject(hash) { |hash, key| hash.fetch(key, {}) }.presence || nil
  end

  def self.validate_output_hash(output_hash)
    output_hash.any? { |k, v| v.blank? } ? false : output_hash
  end

  def self.is_uid_valid?(uid, auth_config_options)
    return uid.present? && (uid.to_s != auth_config_options["empty_guid"].to_s)
  end
end

# There are 2 flavors of SOAP authentication:
# i) Token based - implemented for AAP
# ii) Non token based - implemented for AAO

#===========================================================================================================
# TOKEN BASED
#===========================================================================================================

# Sample Configuration -

# {
#   "setup" => { "wsdl_path" => "app/files/SOAPAuth/aap/wsdl/test.xml", "base_params" => { } },
#   "get_token_url" => "https://www.nfaap.org/sso/sso.aspx?action=gettoken",
#   "set_token_url" => "https://www.nfaap.org/sso/sso.aspx?action=settoken",
#   "empty_guid" => "00000000-0000-0000-0000-000000000000",
#   "login_sequence" => {
#     "execute_method" => { "request" => "app/files/SOAPAuth/aap/templates/execute_method_request.yml", "response" => "app/files/SOAPAuth/aap/templates/execute_method_response.yml" },
#     "web_web_user_login" => { "request" => "app/files/SOAPAuth/aap/templates/web_web_user_login_request.yml", "response" => "app/files/SOAPAuth/aap/templates/web_web_user_login_response.yml" }
#   },
#   "validate_sequence" => {
#     "web_validate" => { "request" => "app/files/SOAPAuth/aap/templates/web_validate_request.yml", "response" => "app/files/SOAPAuth/aap/templates/web_validate_response.yml" }
#   },
#   "validate_member_sequence" => {
#     "get_individual_information" => { "request" => "app/files/SOAPAuth/aap/templates/get_individual_information_request.yml", "response" => "app/files/SOAPAuth/aap/templates/get_individual_information_response.yml" }
#   },
#   "logout_sequence" => {
#     "web_logout" => { "request" => "app/files/SOAPAuth/aap/templates/web_logout_request.yml" }
#   },
#   "validate" => {
#     "criterias" => [ {
#       "criteria" => [ {
#         "attribute" => "is_member",
#         "operator" => "eq",
#         "value" => "1"
#       } ]
#     } ],
#     "fail_message" => "Only members can access the program",
#     "prioritize" => true
#   }
# }


# Process workflow for checking if user is already logged in via SSO:

# 1. User visits mentoring site.
# 2. Mentoring site redirects users to the following URL: config['get_token_url']
# 3. AAP SSO checks to see if the user has any authentication token in the cookie and then respond back via URL: <URL_OF_CALLER>?nfstatus=<STATUS_CODE>&nftoken=<AUTH_TOKEN>&nfstatusdescription=<STATUS_DESCRIPTION>
# 4. If there is a valid token returned, mentoring site is required to validate the token received by calling config['validate_sequence']
# 5. If there is no valid token returned, mentoring site shows login page.


# Process workflow for user login and notifying AAP SSO of successful login:

# 1. User provide/submit their username and password at mentoring site. The mentoring site executes config["login_sequence"]
# 2. Upon successful login, UID for the user is returned
# 3. Mentoring site calls the following URL: config['set_token_url']
# 4. AAP SSO checks to see if token is valid, if so, cookie will be set to allow user to be logged in at other AAP websites.
## AAP SSO will then respond back via URL: <URL_OF_CALLER>?nfstatus=<STATUS_CODE>&nftoken=<AUTH_TOKEN>&nfstatusdescription=<STATUS_DESCRIPTION>

#===========================================================================================================
# NON TOKEN BASED
#===========================================================================================================

# Sample Configuration -

# {
#   "setup" => { "wsdl_path" => "app/files/SOAPAuth/aao/wsdl/production.xml", "base_params" => { } },
#   "empty_guid" => "00000000-0000-0000-0000-000000000000",
#   "login_sequence" => {
#     "authenticate" => { "request" => "app/files/SOAPAuth/aao/templates/authenticate_request.yml", "response" => "app/files/SOAPAuth/aao/templates/authenticate_response.yml" },
#     "web_login" => { "request" => "app/files/SOAPAuth/aao/templates/web_login_request.yml", "response" => "app/files/SOAPAuth/aao/templates/web_login_response.yml" }
#   }
# }

# Process workflow:

# 1. User visits mentoring site's login page and enters username and password.
# 2. Mentoring site executes config["login_sequence"].
# 3. Upon successful login, UID for the user is returned