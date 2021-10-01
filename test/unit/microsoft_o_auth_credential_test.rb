require_relative './../test_helper.rb'

class MicrosoftOAuthCredentialTest < ActiveSupport::TestCase
  def setup
    super
    @microsoft_o_auth_credential = MicrosoftOAuthCredential.new(access_token: "access_token", refresh_token: "refresh_token")
    @start_time = Time.utc(2018, 3, 20, 8, 0, 0)
    @end_time = Time.utc(2018, 3, 20, 20, 0, 0)
  end

  def test_microsoft_get_oauth_client
    client = MicrosoftOAuthCredential.get_oauth_client(redirect_uri: "www.chronus.com/some/redirect/url")
    assert_equal MicrosoftOAuthCredential::AUTHORIZE_URL, client.options[:authorize_url]
    assert_equal MicrosoftOAuthCredential::TOKEN_URL, client.options[:token_url]
    assert_equal "www.chronus.com/some/redirect/url", client.options[:redirect_uri]
  end

  def test_get_raw_response_for_free_busy_slots
    # without :target_api_url set
    oauth2_access_token_obj = @microsoft_o_auth_credential.get_oauth2_access_token_obj
    oauth2_access_token_obj.expects(:get).with('https://outlook.office.com/api/v2.0/me/calendarview?startDateTime=2018-03-20T08:00&endDateTime=2018-03-20T20:00&$select=Start,End&$top=100', {headers: {"Content-type" => "application/json"}})
    @microsoft_o_auth_credential.send(:get_raw_response_for_free_busy_slots, oauth2_access_token_obj, @start_time, @end_time)
    # with :target_api_url set
    some_url = "https://www.chronus.com/some/url?x=1&y=2"
    oauth2_access_token_obj = @microsoft_o_auth_credential.get_oauth2_access_token_obj
    oauth2_access_token_obj.expects(:get).with(some_url, {headers: {"Content-type" => "application/json"}})
    @microsoft_o_auth_credential.send(:get_raw_response_for_free_busy_slots, oauth2_access_token_obj, @start_time, @end_time, target_api_url: some_url)
  end

  def test_fetch_freebusy_ary
    some_value = ['some value']
    assert_equal some_value, @microsoft_o_auth_credential.send(:fetch_freebusy_ary, {"value" => some_value})
  end

  def test_get_url_for_next_set_of_data
    next_url = 'nextUrl'
    assert_equal next_url, @microsoft_o_auth_credential.send(:get_url_for_next_set_of_data, {"@odata.nextLink" => next_url})
  end

  def test_more_data_present_question_mark
    assert_false @microsoft_o_auth_credential.send(:more_data_present?, {})
    assert @microsoft_o_auth_credential.send(:more_data_present?, {"@odata.nextLink" => "next/url"})
  end

  def test_convert_ruby_time_to_microsoft_datetime_str
    assert_equal @start_time.utc.strftime("%Y-%m-%dT%H:%M"), convert_ruby_time_to_microsoft_datetime_str(@start_time)
  end

  def test_convert_provider_datetime_str_to_ruby_time
    obj = {"Start" => {"DateTime" => convert_ruby_time_to_microsoft_datetime_str(@start_time), "TimeZone" => "UTC"}, "End" => {"DateTime" => convert_ruby_time_to_microsoft_datetime_str(@end_time), "TimeZone" => "UTC"}}
    assert_equal @start_time, @microsoft_o_auth_credential.send(:convert_provider_datetime_str_to_ruby_time, obj, boundary: :start)
    assert_equal @end_time, @microsoft_o_auth_credential.send(:convert_provider_datetime_str_to_ruby_time, obj, boundary: :end)
  end

  def test_convert_microsoft_datetime_str_to_ruby_time
    obj = {"Start" => {"DateTime" => convert_ruby_time_to_microsoft_datetime_str(@start_time), "TimeZone" => "UTC"}}
    assert_equal @start_time, @microsoft_o_auth_credential.send(:convert_microsoft_datetime_str_to_ruby_time, obj, "Start")
  end

  def test_get_oauth2_error_code
    assert_equal "500", @microsoft_o_auth_credential.send(:get_oauth2_error_code, OAuth2::Error.new(OpenStruct.new(status: 500)))
  end

  def test_get_oauth2_error_message
    assert_equal "Backend Error", @microsoft_o_auth_credential.send(:get_oauth2_error_message, get_an_error_oauth2_obj)
  end

  def test_refresh_token_expired_question
    assert_false @microsoft_o_auth_credential.send(:refresh_token_expired?, get_an_error_oauth2_obj)
    assert @microsoft_o_auth_credential.send(:refresh_token_expired?, get_an_error_oauth2_obj(code: "\"#{OAuthCredential::INVALID_GRANT}\"", message: "The credentials are revoked."))
  end

  private

  def convert_ruby_time_to_microsoft_datetime_str(time_obj)
    @microsoft_o_auth_credential.send(:convert_ruby_time_to_microsoft_datetime_str, time_obj)
  end

  def get_an_error_oauth2_obj(options = {})
    response = '{"error": ' + (options[:code] || 500).to_s + ',"error_description": "' + (options[:message] || 'Backend Error') + '"}'
    OAuth2::Error.new(OpenStruct.new(parsed: JSON(response), body: response))
  end
end