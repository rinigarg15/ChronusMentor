module OpenAuthUtils
  module Configurations
    module Google
      LOGO = "https://#{CHRONUS_MENTOR_ASSETS_BUCKET}.#{GLOBAL_ASSETS_DOMAIN_URL}/global-assets/images/google-login.png"
      AUTHORIZE_ENDPOINT = "https://accounts.google.com/o/oauth2/v2/auth?scope=profile%20email&prompt=select_account"
      TOKEN_ENDPOINT = "https://www.googleapis.com/oauth2/v4/token"
      API_ENDPOINT = "https://www.googleapis.com/oauth2/v2/userinfo"
      CALLBACK_PARAM_VALUE = "google"
      RESPONSE_TEMPLATE_PROC = Proc.new do |response|
        {
          "uid" => response["email"],
          "import_data" => {
            "Member" => {
              "first_name" => response["given_name"],
              "last_name" => response["family_name"],
              "email" => response["email"]
            }
          }
        }
      end

      def self.is_enabled?
        APP_CONFIG[:google_oauth_client_id].present? && APP_CONFIG[:google_oauth_client_secret].present?
      end

      def self.get_options(_auth_config)
        return {} unless self.is_enabled?
        return {
          "client_id" => APP_CONFIG[:google_oauth_client_id],
          "client_secret" => APP_CONFIG[:google_oauth_client_secret],
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