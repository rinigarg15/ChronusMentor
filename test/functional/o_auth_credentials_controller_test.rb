require_relative './../test_helper.rb'

class OAuthCredentialsControllerTest < ActionController::TestCase
  def setup
    super
    @user = users(:f_mentor)
    @user.program.enable_feature(FeatureName::CALENDAR_SYNC_V2)
    current_user_is @user
  end

  def test_redirect
    source_url = "https://chronus.com/123?a=1&b=2"
    session[:last_visit_url] = source_url
    callback_params_query_str = {c: 3, d: 4}.to_query
    get :redirect, params: { name: GoogleOAuthCredential.name, callback_params: callback_params_query_str }
    assert_equal_hash({controller: "o_auth_credentials", action: "callback", oauth_callback: GoogleOAuthCredential.name}, session[:oauth_callback_params])
    assert_equal @user.program.root, session[:prog_root]
    assert_equal [source_url, callback_params_query_str].join("&"), session[:o_auth_final_redirect]
    assert_nil session[:organization_wide_calendar]
    assert response.redirect?
    assert_not_nil response.location.match(/https:\/\/accounts.google.com\/o\/oauth2\/v2\/auth\?access_type=offline&client_id=.*&prompt=consent&redirect_uri=.*session%2Foauth_callback&response_type=code&scope=https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fcalendar.readonly&state=#{CGI.escape(Base64.urlsafe_encode64(session.id))}/)
  end

  def test_redirect_for_organization_calendar_access
    get :redirect, params: { name: GoogleOAuthCredential.name, organization_wide_calendar: true }, session: { last_visit_url: "https://chronus.com/123?a=1&b=2" }
    assert_equal true, session[:organization_wide_calendar]
    assert response.redirect?
  end

  def test_callback_success
    assert_equal 0, @user.member.o_auth_credentials.size
    target_url = setup_callback_related_values_in_session
    @controller.stubs(:is_open_auth_state_valid?).returns(true)
    code, access_token, refresh_token = ["code", "access_token", "refresh_token"]
    access_token_obj = OAuth2::AccessToken.new(GoogleOAuthCredential.get_oauth_client, access_token, refresh_token: refresh_token)
    OAuth2::Strategy::AuthCode.any_instance.stubs(:get_token).with(code).returns(access_token_obj)
    get :callback, params: { code: code }
    assert response.redirect?
    assert_redirected_to target_url
    assert_equal 1, @user.reload.member.o_auth_credentials.size
    o_auth_credential = @user.member.o_auth_credentials.last
    assert_equal access_token, o_auth_credential.access_token
    assert_equal refresh_token, o_auth_credential.refresh_token
    assert_false @user.member.will_set_availability_slots
    assert_flash_in_page "Your Google calendar is connected."
  end

  def test_callback_failure_no_code
    assert_equal 0, @user.member.o_auth_credentials.size
    target_url = setup_callback_related_values_in_session
    @controller.stubs(:is_open_auth_state_valid?).returns(true)
    Airbrake.expects(:notify).with("(Member id : #{@user.member_id}) (Provider : #{GoogleOAuthCredential.name}) (Error Message : No authorization code!)").once
    get :callback
    assert_equal "We are unable to connect with the calendar at the moment. Please try again later.", flash[:error]
    assert response.redirect?
    assert_redirected_to target_url
    assert_equal 0, @user.reload.member.o_auth_credentials.size
  end

  def test_callback_failure_state_mismatch
    assert_equal 0, @user.member.o_auth_credentials.size
    target_url = setup_callback_related_values_in_session
    @controller.stubs(:is_open_auth_state_valid?).returns(false)
    Airbrake.expects(:notify).with("(Member id : #{@user.member_id}) (Provider : #{GoogleOAuthCredential.name}) (Error Message : State Mismatch!)").once
    get :callback, params: { code: "code" }
    assert_equal "We are unable to connect with the calendar at the moment. Please try again later.", flash[:error]
    assert response.redirect?
    assert_redirected_to target_url
    assert_equal 0, @user.reload.member.o_auth_credentials.size
  end

  def test_disconnect
    GoogleOAuthCredential.create!(access_token: "access_token", refresh_token: "refresh_token", ref_obj: @user.member)
    assert_equal 1, @user.reload.member.o_auth_credentials.size
    source_url = "https://chronus.com/123?a=1&b=2"
    session[:last_visit_url] = source_url
    callback_params_query_str = {c: 3, d: 4}.to_query
    get :disconnect, params: { callback_params: callback_params_query_str }
    assert_equal 0, @user.reload.member.o_auth_credentials.size
    assert response.redirect?
    assert_redirected_to [source_url, callback_params_query_str].join("&")
    assert_flash_in_page "You have successfully disconnected your calendar"
  end

  private

  def setup_callback_related_values_in_session(provider = GoogleOAuthCredential)
    target_url = "https://chronus.com/123?a=1&b=2"
    session[:o_auth_final_redirect] = target_url
    session[:oauth_callback_params] = {OpenAuth::CALLBACK_PARAM => provider.name}
    target_url
  end
end
