require_relative './../../../test_helper'

class OpenAuthTest < ActiveSupport::TestCase

  def setup
    super
    organization = programs(:org_primary)
    organization.security_setting.update_attributes!(linkedin_token: "ABCDE", linkedin_secret: "12345")
    @auth_config = organization.linkedin_oauth
    @options = @auth_config.get_options
  end

  def test_initialize_client
    client = OpenAuth.initialize_client("https://redirect.chronus.com", @options)
    assert client.is_a?(OAuth2::Client)
    assert_equal "ABCDE", client.id
    assert_equal "12345", client.secret
    assert_equal OpenAuthUtils::Configurations::Linkedin::AUTHORIZE_ENDPOINT, client.options[:authorize_url]
    assert_equal OpenAuthUtils::Configurations::Linkedin::TOKEN_ENDPOINT, client.options[:token_url]
    assert_equal "https://redirect.chronus.com", client.options[:redirect_uri]
  end

  def test_initialize_client_invalid
    e = assert_raise RuntimeError do
      OpenAuth.initialize_client("https://redirect.chronus.com", @options.pick("authorize_url"))
    end
    assert_equal "OpenAuth Error: Invalid Initialization Params!", e.message
  end

  def test_authenticate
    data = ["code", "https://redirect.chronus.com"]
    auth_obj = ProgramSpecificAuth.new(@auth_config, data)

    OpenAuth.expects(:initialize_client).with(data[-1], @options).once.returns(OAuth2::Client)
    OpenAuth.expects(:make_api_call).with(OAuth2::AccessToken, @options).once.returns("uid" => "uid12345", "import_data" => "DATA")
    OAuth2::Client.expects(:auth_code).once.returns(OAuth2::Strategy::AuthCode)
    OAuth2::Strategy::AuthCode.expects(:get_token).with(data[0]).once.returns(OAuth2::AccessToken)
    OAuth2::AccessToken.expects(:token).once.returns("access_token")

    assert_equal true, OpenAuth.authenticate?(auth_obj, @options)
    assert_equal "uid12345", auth_obj.uid
    assert_equal "DATA", auth_obj.import_data
    assert_equal "access_token", auth_obj.linkedin_access_token
  end

  def test_make_api_call
    response = { "id" => "123", "firstName" => "Ajay", "lastName" => "Thakur", "emailAddress" => "ajay.thakur@chronus.com" }

    OAuth2::AccessToken.expects(:get).with(OpenAuthUtils::Configurations::Linkedin::API_ENDPOINT).once.returns(OAuth2::Response)
    OAuth2::Response.expects(:status).once.returns(HttpConstants::SUCCESS)
    OAuth2::Response.expects(:content_type).once.returns("application/json")
    OAuth2::Response.expects(:body).once.returns(response.to_json)

    assert_equal_hash( {
      "uid" => "123",
      "import_data" => {
        "Member" => {
          "first_name" => "Ajay",
          "last_name" => "Thakur",
          "email" => "ajay.thakur@chronus.com"
        }
      }
    }, OpenAuth.make_api_call(OAuth2::AccessToken, @options))
  end

  def test_make_api_call_invalid_content_type
    OAuth2::AccessToken.expects(:get).with(OpenAuthUtils::Configurations::Linkedin::API_ENDPOINT).once.returns(OAuth2::Response)
    OAuth2::Response.expects(:status).once.returns(HttpConstants::SUCCESS)
    OAuth2::Response.expects(:content_type).twice.returns("application/xml")
    OAuth2::Response.expects(:body).never

    e = assert_raise RuntimeError do
      OpenAuth.make_api_call(OAuth2::AccessToken, @options)
    end
    assert_equal "OpenAuth Error: Unsupported Content Type application/xml!", e.message
  end

  def test_make_api_call_invalid_response_status
    error_response = "Access token has expired."

    OAuth2::AccessToken.expects(:get).with(OpenAuthUtils::Configurations::Linkedin::API_ENDPOINT).once.returns(OAuth2::Response)
    OAuth2::Response.expects(:status).twice.returns(HttpConstants::FORBIDDEN)
    OAuth2::Response.expects(:content_type).never
    OAuth2::Response.expects(:body).once.returns(error_response)

    e = assert_raise RuntimeError do
      OpenAuth.make_api_call(OAuth2::AccessToken, @options)
    end
    assert_equal "OpenAuth Error: Invalid Response #{HttpConstants::FORBIDDEN}!", e.message
  end
end