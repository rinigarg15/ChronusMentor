require_relative './../../../../test_helper.rb'

class OpenAuthUtils::Configurations::LinkedinTest < ActiveSupport::TestCase

  def test_get_options
    linkedin_oauth = programs(:org_primary).auth_configs.find(&:linkedin_oauth?)
    security_setting = linkedin_oauth.organization.security_setting
    assert linkedin_oauth.organization.linkedin_imports_allowed?

    assert_equal_hash( {
      "client_id" => security_setting.linkedin_token,
      "client_secret" => security_setting.linkedin_secret,
      "authorize_url" => OpenAuthUtils::Configurations::Linkedin::AUTHORIZE_ENDPOINT,
      "token_url" => OpenAuthUtils::Configurations::Linkedin::TOKEN_ENDPOINT,
      "api_endpoint" => OpenAuthUtils::Configurations::Linkedin::API_ENDPOINT,
      "callback_param_value" => OpenAuthUtils::Configurations::Linkedin::CALLBACK_PARAM_VALUE,
      "response_template_proc" => OpenAuthUtils::Configurations::Linkedin::RESPONSE_TEMPLATE_PROC
    }, OpenAuthUtils::Configurations::Linkedin.get_options(linkedin_oauth))
  end

  def test_get_options_linkedin_imports_not_allowed
    linkedin_oauth = programs(:org_primary).auth_configs.find(&:linkedin_oauth?)
    linkedin_oauth.organization.expects(:linkedin_imports_allowed?).returns(false)
    assert_equal_hash({}, OpenAuthUtils::Configurations::Linkedin.get_options(linkedin_oauth))
  end

  def test_response_template_proc
    response = {
      "id" => "123",
      "firstName" => "Roger",
      "lastName" => "Federer",
      "emailAddress" => "roger@rf.com"
    }
    assert_equal_hash({
      "uid" => "123",
      "import_data" => {
        "Member" => {
          "first_name" => "Roger",
          "last_name" => "Federer",
          "email" => "roger@rf.com"
        }
      }
    }, OpenAuthUtils::Configurations::Linkedin::RESPONSE_TEMPLATE_PROC.call(response))
  end
end