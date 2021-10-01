require_relative './../test_helper.rb'

class GoogleOAuthCredentialTest < ActiveSupport::TestCase
  def setup
    super
    @google_o_auth_credential = GoogleOAuthCredential.new(access_token: "access_token", refresh_token: "refresh_token")
    @start_time = Time.utc(2018, 3, 20, 8, 0, 0)
    @end_time = Time.utc(2018, 3, 20, 20, 0, 0)
  end

  def test_google_get_oauth_client
    client = GoogleOAuthCredential.get_oauth_client(redirect_uri: "www.chronus.com/some/redirect/url")
    assert_equal GoogleOAuthCredential::AUTHORIZE_URL, client.options[:authorize_url]
    assert_equal GoogleOAuthCredential::TOKEN_URL, client.options[:token_url]
    assert_equal "www.chronus.com/some/redirect/url", client.options[:redirect_uri]
  end

  def test_get_raw_response_for_free_busy_slots
    oauth2_access_token_obj = @google_o_auth_credential.get_oauth2_access_token_obj
    oauth2_access_token_obj.expects(:post).with(GoogleOAuthCredential::API_ENDPOINT, {
      headers: {"Content-type" => "application/json"},
      body: {
        items: [{id: "primary"}],
        timeMin: convert_ruby_time_to_google_datetime_str(@start_time),
        timeMax: convert_ruby_time_to_google_datetime_str(@end_time)
      }.to_json
    })
    @google_o_auth_credential.send(:get_raw_response_for_free_busy_slots, oauth2_access_token_obj, @start_time, @end_time, {calendar_key: "primary"})
  end

  def test_fetch_freebusy_ary
    primary_check_value = ['primary some value']
    calendar_key_check_value = ['calendar key some value']
    assert_equal primary_check_value, @google_o_auth_credential.send(:fetch_freebusy_ary, {"calendars" => {"primary" => {"busy" => primary_check_value}, "calendar_key" => {"busy" => calendar_key_check_value}}}, {calendar_key: "primary"})
    assert_equal calendar_key_check_value, @google_o_auth_credential.send(:fetch_freebusy_ary, {"calendars" => {"primary" => {"busy" => primary_check_value}, "calendar_key" => {"busy" => calendar_key_check_value}}}, {calendar_key: "calendar_key"})
  end

  def test_more_data_present_question_mark
    assert_false @google_o_auth_credential.send(:more_data_present?, {})
  end

  def test_convert_ruby_time_to_google_datetime_str
    assert_equal @start_time.utc.iso8601, convert_ruby_time_to_google_datetime_str(@start_time)
  end

  def test_convert_provider_datetime_str_to_ruby_time
    obj = {"start" => @start_time.utc.iso8601, "end" => @end_time.utc.iso8601}
    assert_equal @start_time, @google_o_auth_credential.send(:convert_provider_datetime_str_to_ruby_time, obj, boundary: :start)
    assert_equal @end_time, @google_o_auth_credential.send(:convert_provider_datetime_str_to_ruby_time, obj, boundary: :end)
  end

  def test_convert_google_datetime_str_to_ruby_time
    datetime_str = convert_ruby_time_to_google_datetime_str(@start_time)
    assert_equal @start_time, @google_o_auth_credential.send(:convert_google_datetime_str_to_ruby_time, datetime_str)
  end

  def test_get_oauth2_error_code
    assert_equal "500", @google_o_auth_credential.send(:get_oauth2_error_code, get_an_error_oauth2_obj)
  end

  def test_get_oauth2_error_message
    assert_equal "Backend Error", @google_o_auth_credential.send(:get_oauth2_error_message, get_an_error_oauth2_obj)
  end

  def test_refresh_token_expired_question
    response = '{"error": "something"}'
    assert_false @google_o_auth_credential.send(:refresh_token_expired?, OAuth2::Error.new(OpenStruct.new(parsed: JSON(response), body: response)))
    response = '{"error": "' + OAuthCredential::INVALID_GRANT + '"}'
    assert @google_o_auth_credential.send(:refresh_token_expired?, OAuth2::Error.new(OpenStruct.new(parsed: JSON(response), body: response)))
  end

  private

  def convert_ruby_time_to_google_datetime_str(time_obj)
    @google_o_auth_credential.send(:convert_ruby_time_to_google_datetime_str, time_obj)
  end

  def get_an_error_oauth2_obj(options = {})
    response = '{"error": {"code": ' + (options[:code] || 500).to_s + ',"message": "' + (options[:message] || 'Backend Error') + '"}}'
    OAuth2::Error.new(OpenStruct.new(parsed: JSON(response), body: response))
  end
end