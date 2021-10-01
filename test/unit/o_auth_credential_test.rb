require_relative './../test_helper.rb'

class OAuthCredentialTest < ActiveSupport::TestCase
  def setup
    super
    @o_auth_credential = get_tmp_o_auth_credential_obj
    @start_time = Time.utc(2018, 3, 20, 8, 0, 0)
    @end_time = Time.utc(2018, 3, 20, 20, 0, 0)
  end

  def test_get_oauth2_access_token_obj
    access_token_obj = @o_auth_credential.get_oauth2_access_token_obj
    assert access_token_obj.is_a?(OAuth2::AccessToken)
    assert_equal @o_auth_credential.access_token, access_token_obj.token
    assert_equal @o_auth_credential.refresh_token, access_token_obj.refresh_token
  end

  def test_get_free_busy_slots_without_pagination
    @o_auth_credential.stubs(:more_data_present?).returns(false)
    @o_auth_credential.stubs(:get_raw_response_for_free_busy_slots).returns(OpenStruct.new(body: get_response_body))
    hsh = @o_auth_credential.get_free_busy_slots(@start_time, @end_time, {calendar_key: "primary"})
    assert_equal_hash({error_occured: false, busy_slots: [
      { start_time: Time.utc(2018,3,20,10,0,0), end_time: Time.utc(2018,3,20,11, 0,0) },
      { start_time: Time.utc(2018,3,20,14,0,0), end_time: Time.utc(2018,3,20,14,30,0) }
    ]}, hsh)
  end

  def test_get_free_busy_slots_with_calendar_key_option
    @o_auth_credential.stubs(:more_data_present?).returns(false)
    @o_auth_credential.stubs(:get_raw_response_for_free_busy_slots).returns(OpenStruct.new(body: get_response_body_with_multiple_calendars))
    hsh = @o_auth_credential.get_free_busy_slots(@start_time, @end_time, {calendar_key: members(:f_mentor).email})
    assert_equal_hash({error_occured: false, busy_slots: [
      { start_time: Time.utc(2018,3,22,10,0,0), end_time: Time.utc(2018,3,22,11, 0,0) },
      { start_time: Time.utc(2018,3,22,14,0,0), end_time: Time.utc(2018,3,22,14,30,0) }
    ]}, hsh)
  end

  def test_get_free_busy_slots_non_oauth2_related_error_handling
    @o_auth_credential.stubs(:more_data_present?).returns(true, false)
    @o_auth_credential.stubs(:get_raw_response_for_free_busy_slots).returns(OpenStruct.new(body: get_response_body), OpenStruct.new(body: get_response_body_page2))
    hsh = @o_auth_credential.get_free_busy_slots(@start_time, @end_time, {calendar_key: "primary"})
    assert hsh[:error_occured]
    assert_not_nil hsh[:error_message].match(/undefined method/)
    assert hsh[:busy_slots].empty?
  end

  def test_get_free_busy_slots_oauth2_related_error_handling
    @o_auth_credential.stubs(:more_data_present?).returns(false)
    @o_auth_credential.stubs(:get_raw_response_for_free_busy_slots).raises(get_oauth2_error)
    hsh = @o_auth_credential.get_free_busy_slots(@start_time, @end_time, {calendar_key: "primary"})
    assert hsh[:error_occured]
    assert_equal JSON(get_exception_response)['error']['code'].to_s, hsh[:error_code]
    assert_equal JSON(get_exception_response)['error']['message'].to_s, hsh[:error_message]
    assert hsh[:busy_slots].empty?
  end

  def test_get_free_busy_slots_testing_pagination
    @o_auth_credential.stubs(:more_data_present?).returns(true, false)
    @o_auth_credential.stubs(:get_raw_response_for_free_busy_slots).returns(OpenStruct.new(body: get_response_body), OpenStruct.new(body: get_response_body_page2))
    @o_auth_credential.stubs(:get_url_for_next_set_of_data).returns('someUrl')
    hsh = @o_auth_credential.get_free_busy_slots(@start_time, @end_time, {calendar_key: "primary"})
    assert_equal_hash({error_occured: false, busy_slots: [
      { start_time: Time.utc(2018,3,20,10,0,0), end_time: Time.utc(2018,3,20,11, 0,0) },
      { start_time: Time.utc(2018,3,20,14,0,0), end_time: Time.utc(2018,3,20,14,30,0) },
      { start_time: Time.utc(2018,3,20,15,0,0), end_time: Time.utc(2018,3,20,15,30,0) },
      { start_time: Time.utc(2018,3,20,17,0,0), end_time: Time.utc(2018,3,20,18, 0,0) }
    ]}, hsh)
  end

  def test_get_response_from_api_call_and_update_data_obj_bang
    busy_slots = []
    @o_auth_credential.stubs(:get_raw_response_for_free_busy_slots).returns(OpenStruct.new(body: get_response_body), OpenStruct.new(body: get_response_body_page2))
    parsed_repsonse = @o_auth_credential.get_response_from_api_call_and_update_data_obj!(busy_slots, @start_time, @end_time, {calendar_key: "primary"})
    assert_equal_hash({"kind"=>"calendar#freeBusy", "timeMin"=>"2018-03-20T08:00:00.000Z", "timeMax"=>"2018-03-20T20:00:00.000Z", "calendars"=>{"primary"=>{"busy"=>[{"start"=>"2018-03-20T10:00:00Z", "end"=>"2018-03-20T11:00:00Z"}, {"start"=>"2018-03-20T14:00:00Z", "end"=>"2018-03-20T14:30:00Z"}]}}}, parsed_repsonse)
    assert_equal [{start_time: Time.utc(2018,3,20,10,0,0), end_time: Time.utc(2018,3,20,11, 0,0)}, {start_time: Time.utc(2018,3,20,14,0,0), end_time: Time.utc(2018,3,20,14,30,0)}], busy_slots
    parsed_repsonse = @o_auth_credential.get_response_from_api_call_and_update_data_obj!(busy_slots, @start_time, @end_time, {calendar_key: "primary"})
    assert_equal_hash({"kind"=>"calendar#freeBusy", "timeMin"=>"2018-03-20T08:00:00.000Z", "timeMax"=>"2018-03-20T20:00:00.000Z", "calendars"=>{"primary"=>{"busy"=>[{"start"=>"2018-03-20T15:00:00Z", "end"=>"2018-03-20T15:30:00Z"}, {"start"=>"2018-03-20T17:00:00Z", "end"=>"2018-03-20T18:00:00Z"}]}}}, parsed_repsonse)
    assert_equal [{start_time: Time.utc(2018,3,20,10,0,0), end_time: Time.utc(2018,3,20,11,0,0)}, {start_time: Time.utc(2018,3,20,14,0,0), end_time: Time.utc(2018,3,20,14,30,0)}, {start_time: Time.utc(2018,3,20,15,0,0), end_time: Time.utc(2018,3,20,15,30,0)}, {start_time: Time.utc(2018,3,20,17,0,0), end_time: Time.utc(2018,3,20,18,0,0)}], busy_slots
  end

  def test_update_busy_slots_ary_bang
    busy_slots = []
    @o_auth_credential.stubs(:convert_provider_datetime_str_to_ruby_time).returns('1s', '1e', '2s', '2e', '3s', '3e')
    @o_auth_credential.update_busy_slots_ary!(busy_slots, [1, 2])
    assert_equal [{start_time: '1s', end_time: '1e'}, {start_time: '2s', end_time: '2e'}], busy_slots
    @o_auth_credential.update_busy_slots_ary!(busy_slots, [3])
    assert_equal [{start_time: '1s', end_time: '1e'}, {start_time: '2s', end_time: '2e'}, {start_time: '3s', end_time: '3e'}], busy_slots
  end

  def test_get_parsed_response_for_free_busy_slots
    @o_auth_credential.stubs(:get_raw_response_for_free_busy_slots).returns(OpenStruct.new(body: get_response_body))
    parsed_repsonse = @o_auth_credential.get_parsed_response_for_free_busy_slots(@start_time, @end_time, {calendar_key: "primary"})
    assert_equal_hash({"kind"=>"calendar#freeBusy", "timeMin"=>"2018-03-20T08:00:00.000Z", "timeMax"=>"2018-03-20T20:00:00.000Z", "calendars"=>{"primary"=>{"busy"=>[{"start"=>"2018-03-20T10:00:00Z", "end"=>"2018-03-20T11:00:00Z"}, {"start"=>"2018-03-20T14:00:00Z", "end"=>"2018-03-20T14:30:00Z"}]}}}, parsed_repsonse)
  end

  def test_get_parsed_response
    assert_equal_hash({"kind"=>"calendar#freeBusy", "timeMin"=>"2018-03-20T08:00:00.000Z", "timeMax"=>"2018-03-20T20:00:00.000Z", "calendars"=>{"primary"=>{"busy"=>[{"start"=>"2018-03-20T10:00:00Z", "end"=>"2018-03-20T11:00:00Z"}, {"start"=>"2018-03-20T14:00:00Z", "end"=>"2018-03-20T14:30:00Z"}]}}}, @o_auth_credential.get_parsed_response(OpenStruct.new(body: get_response_body)))
  end

  def test_refresh_success
    assert_equal 'access_token', @o_auth_credential.access_token
    assert_equal 'refresh_token', @o_auth_credential.refresh_token
    OAuth2::AccessToken.any_instance.stubs(:refresh!).returns(OAuth2::AccessToken.new(GoogleOAuthCredential.get_oauth_client, 'new_access_token', refresh_token: 'new_refresh_token'))
    @o_auth_credential.expects(:save!).once.returns(true)
    assert_equal_hash({ refreshed_successfully: true }, @o_auth_credential.refresh)
    assert_equal 'new_access_token', @o_auth_credential.access_token
    assert_equal 'new_refresh_token', @o_auth_credential.refresh_token
  end

  def test_refresh_general_failure
    OAuth2::AccessToken.any_instance.stubs(:refresh!).raises(get_oauth2_error)
    @o_auth_credential.stubs(:refresh_token_expired?).returns(false)
    @o_auth_credential.expects(:destroy).never
    assert_equal_hash({refreshed_successfully: false, error_code: "500", error_message: "Backend Error"}, @o_auth_credential.refresh)
  end

  def test_refresh_access_revoked_failure
    OAuth2::AccessToken.any_instance.stubs(:refresh!).raises(get_oauth2_error)
    @o_auth_credential.stubs(:refresh_token_expired?).returns(true)
    @o_auth_credential.expects(:destroy).once.returns(true)
    assert_equal_hash({refreshed_successfully: false, error_code: "500", error_message: "Backend Error"}, @o_auth_credential.refresh)
  end

  def test_handle_exception
    Airbrake.expects(:notify).with('GoogleOAuthCredential (id: nil) Error Code (N/A) : <no error message>').once
    assert_equal_hash({error_occured: true, error_message: "", busy_slots: []}, @o_auth_credential.handle_exception(nil, @start_time, @end_time))
    Airbrake.expects(:notify).with('GoogleOAuthCredential (id: nil) Error Code (N/A) : some error message').once
    assert_equal_hash({error_occured: true, error_message: "some error message", busy_slots: []}, @o_auth_credential.handle_exception(OpenStruct.new(message: "some error message"), @start_time, @end_time))
    Airbrake.expects(:notify).with('GoogleOAuthCredential (id: nil) Error Code (500) : Backend Error').once
    assert_equal_hash({error_occured: true, error_code: "500", error_message: "Backend Error", busy_slots: []}, @o_auth_credential.handle_exception(get_oauth2_error, @start_time, @end_time))
  end

  def test_handle_oauth2_exception_non_401_error
    assert_equal_hash({error_occured: true, error_code: "500", error_message: "Backend Error", busy_slots: []}, @o_auth_credential.handle_exception(get_oauth2_error, @start_time, @end_time))
  end

  def test_handle_oauth2_exception_401_error_dont_refresh
    @o_auth_credential.expects(:refresh).never
    assert_equal_hash({error_occured: true, error_code: "401", error_message: "Invalid Credentials", busy_slots: []}, @o_auth_credential.handle_exception(get_oauth2_error(code: 401, message: "Invalid Credentials"), @start_time, @end_time, dont_refresh: true))
  end

  def test_handle_oauth2_exception_401_error_with_refresh_success
    @o_auth_credential.expects(:refresh).once.returns({refreshed_successfully: true})
    @o_auth_credential.expects(:get_free_busy_slots).once.returns({error_occured: false, busy_slots: [1,2,3]})
    assert_equal_hash({error_occured: false, busy_slots: [1,2,3]}, @o_auth_credential.handle_exception(get_oauth2_error(code: 401, message: "Invalid Credentials"), @start_time, @end_time))
  end

  def test_handle_oauth2_exception_401_error_with_refresh_failure
    @o_auth_credential.expects(:refresh).once.returns({refreshed_successfully: false, error_code: "403", error_message: "Daily Limit Exceeded"})
    @o_auth_credential.expects(:get_free_busy_slots).never
    assert_equal_hash({error_occured: true, error_code: "403", error_message: "Daily Limit Exceeded", busy_slots: []}, @o_auth_credential.handle_exception(get_oauth2_error(code: 401, message: "Invalid Credentials"), @start_time, @end_time))
  end

  def test_exception_return_value
    assert_equal_hash({error_occured: true, error_code: "code", error_message: "message", busy_slots: []}, @o_auth_credential.send(:exception_return_value, code: 'code', message: 'message'))
  end

  def test_supported_providers
    assert_equal_unordered [GoogleOAuthCredential, OutlookOAuthCredential, Office365OAuthCredential], OAuthCredential::Provider.supported
    assert_equal_unordered ["https://accounts.google.com/o/oauth2/v2/auth?prompt=consent&scope=https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fcalendar.readonly&access_type=offline", "https://login.microsoftonline.com/common/oauth2/v2.0/authorize?scope=offline_access+https%3A%2F%2Foutlook.office.com%2FCalendars.Read"], OAuthCredential::Provider.supported_provider_urls
  end

  private

  def get_oauth2_error(options = {})
    OAuth2::Error.new(OpenStruct.new(parsed: JSON(get_exception_response(options)), body: get_exception_response(options)))
  end

  def get_tmp_o_auth_credential_obj(options = {})
    (options[:klass] || "GoogleOAuthCredential").constantize.new(access_token: "access_token", refresh_token: "refresh_token")
  end

  def get_response_body
    '{
      "kind": "calendar#freeBusy",
      "timeMin": "2018-03-20T08:00:00.000Z",
      "timeMax": "2018-03-20T20:00:00.000Z",
      "calendars": {
        "primary": {
          "busy": [
            {
             "start": "2018-03-20T10:00:00Z",
             "end": "2018-03-20T11:00:00Z"
            },
            {
             "start": "2018-03-20T14:00:00Z",
             "end": "2018-03-20T14:30:00Z"
            }
          ]
        }
      }
    }'
  end

  def get_response_body_page2
    '{
      "kind": "calendar#freeBusy",
      "timeMin": "2018-03-20T08:00:00.000Z",
      "timeMax": "2018-03-20T20:00:00.000Z",
      "calendars": {
        "primary": {
          "busy": [
            {
             "start": "2018-03-20T15:00:00Z",
             "end": "2018-03-20T15:30:00Z"
            },
            {
             "start": "2018-03-20T17:00:00Z",
             "end": "2018-03-20T18:00:00Z"
            }
          ]
        }
      }
    }'
  end

  def get_response_body_with_multiple_calendars
    '{
      "kind": "calendar#freeBusy",
      "timeMin": "2018-03-20T08:00:00.000Z",
      "timeMax": "2018-03-20T20:00:00.000Z",
      "calendars": {
        "primary": {
          "busy": [
            {
             "start": "2018-03-20T10:00:00Z",
             "end": "2018-03-20T11:00:00Z"
            },
            {
             "start": "2018-03-20T14:00:00Z",
             "end": "2018-03-20T14:30:00Z"
            }
          ]
        },
        "robert@example.com": {
          "busy": [
            {
             "start": "2018-03-22T10:00:00Z",
             "end": "2018-03-22T11:00:00Z"
            },
            {
             "start": "2018-03-22T14:00:00Z",
             "end": "2018-03-22T14:30:00Z"
            }
          ]
        }
      }
    }'
  end

  def get_exception_response(options = {})
    '{"error": {"code": ' + (options[:code] || 500).to_s + ',"message": "' + (options[:message] || 'Backend Error') + '"}}'
  end
end