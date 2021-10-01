module OpenAuthUtils
  module Configurations
    module Linkedin
      LOGO = "https://#{CHRONUS_MENTOR_ASSETS_BUCKET}.#{GLOBAL_ASSETS_DOMAIN_URL}/global-assets/images/linkedin-login.png"
      AUTHORIZE_ENDPOINT = "https://www.linkedin.com/oauth/v2/authorization?scope=r_basicprofile%20r_emailaddress"
      TOKEN_ENDPOINT = "https://www.linkedin.com/oauth/v2/accessToken"
      API_ENDPOINT = "https://api.linkedin.com/v1/people/~:(id,first-name,last-name,email-address)?format=json"
      CALLBACK_PARAM_VALUE = "linkedin"
      RESPONSE_TEMPLATE_PROC = Proc.new do |response|
        {
          "uid" => response["id"],
          "import_data" => {
            "Member" => {
              "first_name" => response["firstName"],
              "last_name" => response["lastName"],
              "email" => response["emailAddress"]
            }
          }
        }
      end

      def self.get_options(auth_config)
        organization = auth_config.organization
        return {} unless organization.linkedin_imports_allowed?

        security_setting = organization.security_setting
        return {
          "client_id" => security_setting.linkedin_token,
          "client_secret" => security_setting.linkedin_secret,
          "authorize_url" => AUTHORIZE_ENDPOINT,
          "token_url" => TOKEN_ENDPOINT,
          "api_endpoint" => API_ENDPOINT,
          "callback_param_value" => CALLBACK_PARAM_VALUE,
          "response_template_proc" => RESPONSE_TEMPLATE_PROC
        }
      end
    end
  end
end