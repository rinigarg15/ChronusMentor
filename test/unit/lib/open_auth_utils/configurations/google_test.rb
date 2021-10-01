require_relative './../../../../test_helper.rb'

class OpenAuthUtils::Configurations::GoogleTest < ActiveSupport::TestCase

  def test_is_enabled
    modify_const(:APP_CONFIG, google_oauth_client_id: "client-id") do
      assert_false OpenAuthUtils::Configurations::Google.is_enabled?
    end
    modify_const(:APP_CONFIG, google_oauth_client_secret: "client-secret") do
      assert_false OpenAuthUtils::Configurations::Google.is_enabled?
    end
    modify_const(:APP_CONFIG, google_oauth_client_id: "client-id", google_oauth_client_secret: "client-secret") do
      assert OpenAuthUtils::Configurations::Google.is_enabled?
    end
  end

  def test_get_options
    modify_const(:APP_CONFIG, {}) do
      assert_equal_hash({}, OpenAuthUtils::Configurations::Google.get_options(nil))
    end

    modify_const(:APP_CONFIG, google_oauth_client_id: "google-client-id", google_oauth_client_secret: "google-client-secret") do
      assert_equal_hash( {
        "client_id" => "google-client-id",
        "client_secret" => "google-client-secret",
        "authorize_url" => OpenAuthUtils::Configurations::Google::AUTHORIZE_ENDPOINT,
        "token_url" => OpenAuthUtils::Configurations::Google::TOKEN_ENDPOINT,
        "api_endpoint" => OpenAuthUtils::Configurations::Google::API_ENDPOINT,
        "callback_param_value" => OpenAuthUtils::Configurations::Google::CALLBACK_PARAM_VALUE,
        "response_template_proc" => OpenAuthUtils::Configurations::Google::RESPONSE_TEMPLATE_PROC
      }, OpenAuthUtils::Configurations::Google.get_options(nil))
    end
  end

  def test_response_template_proc
    response = {
      "given_name" => "Sachin",
      "family_name" => "Tendulkar",
      "email" => "sachin@chronus.com"
    }

    assert_equal_hash( {
      "uid" => "sachin@chronus.com",
      "import_data" => {
        "Member" => {
          "first_name" => "Sachin",
          "last_name" => "Tendulkar",
          "email" => "sachin@chronus.com"
        }
      }
    }, OpenAuthUtils::Configurations::Google::RESPONSE_TEMPLATE_PROC.call(response))
  end
end