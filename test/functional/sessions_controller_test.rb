require_relative './../test_helper.rb'

class SessionsControllerTest < ActionController::TestCase

  def setup
    super
    @user = users(:f_mentor)
    @member = @user.member
    @program = @user.program
    @organization = @program.organization

    @controller.stubs(:is_mobile_app?).returns(true)
    assert @controller.respond_to?(:mobile_platform)
    @controller.stubs(:mobile_platform).returns(MobileDevice::Platform::IOS)
  end

  def test_new_when_loggedin
    current_member_is @member
    https_get :new
    assert_redirected_to root_organization_path(cjs_close_iab_refresh: 1)
  end

  def test_new_when_authenticated_externally
    session[:new_custom_auth_user] = { auth_config_id: @organization.linkedin_oauth.id, @organization.id => "uid" }
    current_organization_is @organization
    https_get :new
    assert_redirected_to root_organization_path(cjs_close_iab_refresh: 1)
  end

  def test_new_when_loggedin_at_program_level
    current_user_is @user
    https_get :new
    assert_redirected_to program_root_path(cjs_close_iab_refresh: 1)
  end

  def test_new_when_authenticated_externally_at_program_level
    session[:new_custom_auth_user] = { auth_config_id: @organization.linkedin_oauth.id, @organization.id => "uid" }
    current_program_is @program
    https_get :new
    assert_redirected_to program_root_path(cjs_close_iab_refresh: 1)
  end

  def test_new_strict_mode
    session[:signup_code] = "signup_code"
    session[:signup_roles] = {}
    session[:invite_code] = "invite_code"
    session[:reset_code] = "reset_code"
    session[:auth_config_id] = { @organization.id => @organization.chronus_auth.id }

    current_organization_is :org_primary
    https_get :new, params: { mode: SessionsController::LoginMode::STRICT}
    assert_response :success
    assert_nil assigns(:auth_config)
    assert_equal SessionsController::LoginMode::STRICT, session[:login_mode]
    assert_nil session[:signup_code] || session[:signup_roles] || session[:invite_code] || session[:reset_code]
  end

  def test_new_reset_strict_mode
    session[:login_mode] = SessionsController::LoginMode::STRICT
    current_organization_is @organization
    https_get :new
    assert_response :success
    assert_nil session[:login_mode]
  end

  def test_new_dont_reset_strict_mode_when_auth_config_id_param
    session[:login_mode] = SessionsController::LoginMode::STRICT
    current_organization_is @organization
    https_get :new, params: { auth_config_id: @organization.chronus_auth.id}
    assert_response :success
    assert_equal SessionsController::LoginMode::STRICT, session[:login_mode]
  end

  def test_new_dont_reset_strict_mode_when_sso_attr
    @controller.expects(:any_sso_attributes_present?).at_least(0).returns(true)
    session[:login_mode] = SessionsController::LoginMode::STRICT
    current_organization_is @organization
    https_get :new
    assert_response :success
    assert_equal SessionsController::LoginMode::STRICT, session[:login_mode]
  end

  def test_new_store_signup_vars_in_session
    current_program_is @program
    https_get :new, params: { signup_roles: [RoleConstants::MENTOR_NAME]}
    assert_response :success
    assert_equal_hash( { @program.root => [RoleConstants::MENTOR_NAME] }, session[:signup_roles])
  end

  def test_new
    current_organization_is @organization
    https_get :new
    assert_response :success
    assert_auth_config(nil)
    assert assigns(:login_active)
    assert_equal @organization.security_setting, assigns(:security_setting)
    assert_equal 1, assigns(:login_sections).size
  end

  def test_new_initiate_chronus_auth
    chronus_auth = @organization.chronus_auth

    session[:email] = @member.email
    current_organization_is @organization
    https_get :new, params: { auth_config_id: chronus_auth.id}
    assert_response :success
    assert_auth_config(chronus_auth)
    assert_equal @member.email, assigns(:login)
  end

  def test_new_initiate_openssl_login
    openssl_auth = create_openssl_auth

    current_program_is @program
    https_get :new, params: { auth_config_id: openssl_auth.id}
    assert_redirected_to "https://openssl.chronus.com"
    assert_auth_config(openssl_auth)
    assert_equal @program.root, session[:prog_root]
  end

  def test_new_complete_openssl_login
    openssl_auth = create_openssl_auth
    @member.login_identifiers.create!(auth_config: openssl_auth, identifier: "uid")

    private_key = mock
    OpenSSL::PKey::RSA.expects(:new).at_least(0).returns(private_key)
    private_key.expects(:private_decrypt).with(Base64::decode64("12345")).returns("uid")
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::LOGIN).once
    @controller.expects(:finished_chronus_ab_test_only_use_cookie).with(ProgramAbTest::Experiment::MOBILE_APP_LOGIN_WORKFLOW, true, true).once
    Pendo.expects(:reset_pendo_guide_seen_data)

    session[:prog_root] = @program.root
    current_organization_is @organization
    https_get :new, params: { login_data: "12345"}
    assert_redirected_to program_root_path(cjs_close_iab_refresh: 1, lst: ProgramSpecificAuth::StatusParams::AUTHENTICATION_SUCCESS)
    assert_auth_config(openssl_auth)
    assert_equal @user, assigns(:current_user)
    assert_equal @program, assigns(:current_program)
    assert_nil session[:prog_root]
    assert_equal [], session[:closed_circles_in_publish_circle_widget_ids]
  end

  def test_new_complete_token_login
    chronus_auth = @organization.chronus_auth
    login_token = @member.login_tokens.first
    current_organization_is @organization
    login_token.update_column(:created_at, Time.now)
    @controller.expects(:finished_chronus_ab_test_only_use_cookie).with(ProgramAbTest::Experiment::MOBILE_APP_LOGIN_WORKFLOW, true, true)
    https_get :new, params: { auth_config_id: chronus_auth.id, token_code: login_token.token_code}
    assert_redirected_to root_organization_path(cjs_close_iab_refresh: 1, lst: ProgramSpecificAuth::StatusParams::AUTHENTICATION_SUCCESS)
    assert_auth_config(chronus_auth)
    assert_equal @member, assigns(:current_member)
  end

  def test_mobile_app_login_finish_experiment_cross_server
    chronus_auth = @organization.chronus_auth
    login_token = @member.login_tokens.first
    current_organization_is @organization
    login_token.update_column(:created_at, Time.now)
    modify_const(:APP_CONFIG, mobile_app_origin_server: false) do
      @controller.expects(:finished_chronus_ab_test_only_use_cookie).never
      Experiments::MobileAppLoginWorkflow.expects(:finish_cross_server_experiments).with("uniq_token")
      https_get :new, params: { auth_config_id: chronus_auth.id, token_code: login_token.token_code, uniq_token: "uniq_token"}
      assert_redirected_to root_organization_path(cjs_close_iab_refresh: 1, lst: ProgramSpecificAuth::StatusParams::AUTHENTICATION_SUCCESS)
    end
  end

  def test_new_token_login_with_invalid_code
    chronus_auth = @organization.chronus_auth
    current_organization_is @organization
    https_get :new, params: { auth_config_id: chronus_auth.id, token_code: "random code"}
    assert_response :success
    assert_auth_config(chronus_auth)
    assert_false assigns(:current_member)
  end

  def test_new_bbnc_login_when_xhr
    bbnc_auth = create_bbnc_auth

    current_organization_is @organization
    https_get :new, xhr: true, params: { auth_config_id: bbnc_auth.id}
    assert_response 401
  end

  def test_new_initiate_bbnc_login
    bbnc_auth = create_bbnc_auth

    current_organization_is @organization
    https_get :new, params: { auth_config_id: bbnc_auth.id}
    assert_redirected_to "https://bbnc.chronus.com&redirect=#{new_session_url(auth_config_id: bbnc_auth.id)}"
    assert_auth_config(bbnc_auth)
  end

  def test_new_complete_bbnc_login
    bbnc_auth = create_bbnc_auth
    @member.login_identifiers.create!(auth_config: bbnc_auth, identifier: "uid")
    ts = Time.now.round(7).iso8601(7)
    sig = Digest::MD5.hexdigest("uid" + ts + "abc")

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::LOGIN).once
    @controller.expects(:finished_chronus_ab_test_only_use_cookie).with(ProgramAbTest::Experiment::MOBILE_APP_LOGIN_WORKFLOW, true, true).once
    Pendo.expects(:reset_pendo_guide_seen_data)
    current_organization_is @organization
    https_get :new, params: { userid: "uid", ts: ts, sig: sig}
    assert_redirected_to root_organization_path(cjs_close_iab_refresh: 1, lst: ProgramSpecificAuth::StatusParams::AUTHENTICATION_SUCCESS)
    assert_auth_config(bbnc_auth)
    assert_equal @member, assigns(:current_member)
    assert_nil assigns(:current_user)
  end

  def test_new_initiate_cookie_auth
    cookie_auth = create_cookie_auth

    current_program_is @program
    https_get :new, params: { auth_config_id: cookie_auth.id}
    assert_redirected_to "https://cookie.chronus.com"
    assert_auth_config(cookie_auth)
  end

  def test_new_complete_cookie_auth_failure
    cookie_auth = create_cookie_auth

    cookies[:enc_constitid] = { value: EncryptionEngine::DES.new("DES", "TESTiInt").encrypt("Tes1t") }
    current_program_is @program
    https_get :new
    assert_redirected_to program_root_path(cjs_close_iab_refresh: 1, lst: ProgramSpecificAuth::StatusParams::AUTHENTICATION_FAILURE, org_id: @organization.id)
    assert_equal "We're sorry, but access to this page is limited to SPE members only. If you believe you received this page in error, please contact Customer Service at 1.972.952.9393 or service@spe.org. If you are not a member, please use the Back button on your browser to continue your session on SPE.org.", flash[:error]
    assert_auth_config(cookie_auth)
    assert_false assigns(:current_member)
  end

  def test_new_complete_cookie_auth
    cookie_auth = create_cookie_auth
    @member.login_identifiers.create!(auth_config: cookie_auth, identifier: "Tes1t")

    cookies[:enc_constitid] = { value: EncryptionEngine::DES.new("DES", "TESTiInt").encrypt("Tes1t") }
    current_program_is @program
    https_get :new
    assert_redirected_to program_root_path(cjs_close_iab_refresh: 1, lst: ProgramSpecificAuth::StatusParams::AUTHENTICATION_SUCCESS)
    assert_auth_config(cookie_auth)
    assert_equal @user, assigns(:current_user)
  end

  def test_new_complete_cookie_auth_when_encoded_chars
    cookie_auth = create_cookie_auth
    @member.login_identifiers.create!(auth_config: cookie_auth, identifier: "3463268")

    cookies[:enc_constitid] = { value: EncryptionEngine::DES.new("DES", "TESTiInt").encrypt("3463268").tr("+", " ") }
    current_organization_is @organization
    https_get :new
    assert_redirected_to root_organization_path(cjs_close_iab_refresh: 1, lst: ProgramSpecificAuth::StatusParams::AUTHENTICATION_SUCCESS)
    assert_auth_config(cookie_auth)
    assert_equal @member, assigns(:current_member)
  end

  def test_new_initiate_soap_auth
    soap_auth = create_soap_auth(false)

    current_program_is @program
    https_get :new, params: { auth_config_id: soap_auth.id}
    assert_response :success
    assert_auth_config(soap_auth)
  end

  def test_new_initiate_token_based_soap_auth
    soap_auth = create_soap_auth

    current_program_is @program
    https_get :new, params: { auth_config_id: soap_auth.id}
    assert_redirected_to "https://soap.chronus.com&nfredirect=#{new_session_url}"
    assert_auth_config(soap_auth)
  end

  def test_new_initiate_token_based_soap_auth_when_empty_guid
    soap_auth = create_soap_auth

    current_program_is @program
    https_get :new, params: { nftoken: "00000000-0000-0000-0000-000000000000"}
    assert_response :success
    assert_auth_config(soap_auth)
    assert_equal 2, assigns(:login_sections).size
  end

  def test_new_complete_token_based_soap_auth
    soap_auth = create_soap_auth
    @member.login_identifiers.create!(auth_config: soap_auth, identifier: "uid")
    token = "12345678-9012-3456-7890-123456789012"

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::LOGIN).once
    @controller.expects(:finished_chronus_ab_test_only_use_cookie).with(ProgramAbTest::Experiment::MOBILE_APP_LOGIN_WORKFLOW, true, true).once
    Pendo.expects(:reset_pendo_guide_seen_data)
    SOAPAuth.expects(:validate).with(soap_auth.get_options, { "nftoken" => token } ).once.returns("uid" => "uid")
    current_program_is @program
    https_get :new, params: { nftoken: token}
    assert_redirected_to program_root_path(cjs_close_iab_refresh: 1, lst: ProgramSpecificAuth::StatusParams::AUTHENTICATION_SUCCESS)
    assert_auth_config(soap_auth)
    assert_equal @user, assigns(:current_user)
    assert_equal token, session[:nftoken]
  end

  def test_new_initiate_saml_auth
    saml_auth = create_saml_auth(@organization)

    current_organization_is @organization
    https_get :new, params: { auth_config_id: saml_auth.id}
    assert_response :redirect
    assert_auth_config(saml_auth)
    assert_match "https:\/\/saml.chronus.com?SAMLRequest=", CGI.unescape(@response.location)
    assert CGI.unescape(@response.location).match("\n").present?
  end

  def test_new_initiate_saml_auth_with_strict_encode64
    saml_auth = create_saml_auth(@organization, {}, {"strict_encoding" => true})
    current_organization_is @organization
    https_get :new, params: { auth_config_id: saml_auth.id}
    assert_response :redirect
    assert_auth_config(saml_auth)

    assert_match "https:\/\/saml.chronus.com?SAMLRequest=", CGI.unescape(@response.location)
    assert_nil CGI.unescape(@response.location).match("\n")
  end

  def test_new_initiate_saml_auth_when_secure_access
    saml_auth = create_saml_auth(@organization)

    mock_parent_session(@organization, "abcd")
    current_subdomain_is SECURE_SUBDOMAIN
    https_get :new, params: { auth_config_id: saml_auth.id, SID_PARAM_NAME => "abcd"}
    assert_response :redirect
    assert_auth_config(saml_auth)
    assert_match "https:\/\/saml.chronus.com?SAMLRequest=", CGI.unescape(@response.location)
    assert session[:continue_secure_access]
  end

  def test_new_initiate_open_auth
    open_auth = @organization.linkedin_oauth

    ActionController::TestSession.any_instance.stubs(:id).returns("session-id")
    current_organization_is @organization
    https_get :new, params: { auth_config_id: open_auth.id}
    assert_open_auth_redirect(@organization, "session-id")
    assert_auth_config(open_auth)
    assert_equal Base64.urlsafe_encode64("session-id"), session[OpenAuth::STATE_VARIABLE_IN_SESSION]
  end

  def test_new_complete_open_auth
    open_auth = @organization.linkedin_oauth
    @member.login_identifiers.create!(auth_config: open_auth, identifier: "12345")
    auth_obj = ProgramSpecificAuth.new(open_auth, "")
    auth_obj.uid = "12345"
    auth_obj.linkedin_access_token = "li12345"
    auth_obj.status = ProgramSpecificAuth::Status::AUTHENTICATION_SUCCESS
    auth_obj.member = @member
    encoded_state = Base64.urlsafe_encode64("abcd")

    @request.session[OpenAuth::STATE_VARIABLE_IN_SESSION] = encoded_state
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::LOGIN).once
    @controller.expects(:finished_chronus_ab_test_only_use_cookie).with(ProgramAbTest::Experiment::MOBILE_APP_LOGIN_WORKFLOW, true, true).once
    Pendo.expects(:reset_pendo_guide_seen_data)
    @controller.expects(:get_open_auth_callback_url).returns("https://oauthcallback.chronus.com").once
    ProgramSpecificAuth.expects(:authenticate).with(open_auth, "OAUTH_CODE", "https://oauthcallback.chronus.com").once.returns(auth_obj)

    current_organization_is @organization
    https_get :new, params: { code: "OAUTH_CODE", state: encoded_state, OpenAuth::CALLBACK_PARAM => OpenAuthUtils::Configurations::Linkedin::CALLBACK_PARAM_VALUE}
    assert_redirected_to root_organization_path(domain: @organization.domain, subdomain: @organization.subdomain, cjs_close_iab_refresh:1, lst: ProgramSpecificAuth::StatusParams::AUTHENTICATION_SUCCESS)
    assert_auth_config(open_auth)
    assert_equal @member, assigns(:current_member)
    assert_equal "li12345", @member.reload.linkedin_access_token
  end

  def test_new_complete_open_auth_when_new_user
    open_auth = @organization.linkedin_oauth
    auth_obj = ProgramSpecificAuth.new(open_auth, "")
    auth_obj.uid = "12345"
    auth_obj.linkedin_access_token = "li12345"
    auth_obj.status = ProgramSpecificAuth::Status::NO_USER_EXISTENCE
    encoded_state = Base64.urlsafe_encode64("abcd")

    @request.session[OpenAuth::STATE_VARIABLE_IN_SESSION] = encoded_state
    @controller.expects(:get_open_auth_callback_url).returns("https://oauthcallback.chronus.com").once
    ProgramSpecificAuth.expects(:authenticate).with(open_auth, "OAUTH_CODE", "https://oauthcallback.chronus.com").once.returns(auth_obj)

    current_organization_is @organization
    https_get :new, params: { code: "OAUTH_CODE", state: encoded_state, OpenAuth::CALLBACK_PARAM => OpenAuthUtils::Configurations::Linkedin::CALLBACK_PARAM_VALUE}
    assert_redirected_to root_organization_path(domain: @organization.domain, subdomain: @organization.subdomain, cjs_close_iab_refresh:1, org_id: @organization.id, lst: ProgramSpecificAuth::StatusParams::NO_USER_EXISTENCE)
    assert_auth_config(open_auth)
    assert_false assigns(:current_member)
    assert_equal_hash( { @organization.id => "12345", auth_config_id: open_auth.id, is_uid_email: false }, session["new_custom_auth_user"])
    assert_equal "li12345", session["linkedin_access_token"]
  end

  def test_new_open_auth_when_invalid_state
    open_auth = @organization.google_oauth
    encoded_state = Base64.urlsafe_encode64("abcd")

    @request.session[OpenAuth::STATE_VARIABLE_IN_SESSION] = encoded_state
    ProgramSpecificAuth.expects(:authenticate).never
    current_organization_is @organization
    e = assert_raise RuntimeError do
      https_get :new, params: { code: "OAUTH_CODE", state: "invalid", OpenAuth::CALLBACK_PARAM => OpenAuthUtils::Configurations::Google::CALLBACK_PARAM_VALUE}
    end
    assert_equal "OpenAuth Error: State Mismatch!", e.message
    assert_auth_config(open_auth)
    assert_false assigns(:current_member)
  end

  def test_new_open_auth_when_error_param
    open_auth = @organization.google_oauth

    ProgramSpecificAuth.expects(:authenticate).never
    current_organization_is @organization
    https_get :new, params: { error: "1", code: "OAUTH_CODE", OpenAuth::CALLBACK_PARAM => OpenAuthUtils::Configurations::Google::CALLBACK_PARAM_VALUE}
    assert_redirected_to root_path(lst: ProgramSpecificAuth::StatusParams::AUTHENTICATION_FAILURE, org_id: @organization.id)
    assert_equal "Login failed. Try again", flash[:error]
    assert_auth_config(open_auth)
    assert_false assigns(:current_member)
  end

  def test_new_chronussupport
    current_organization_is @organization
    https_get :new, params: { chronussupport: "true"}
    assert_response :success
    assert_chronussupport_auth

    assert_select "form" do
      assert_select "input[type=hidden][name=chronussupport][value=true]"
    end
  end

  def test_basic_auth
    current_organization_is @organization
    @request.env["HTTP_AUTHORIZATION"] = "Basic " + Base64::encode64("#{@member.email}:monkey")
    https_get :new
    assert assigns(:current_member)
  end

  def test_basic_auth_with_wrong_password
    current_organization_is @organization
    @request.env["HTTP_AUTHORIZATION"] = "Basic " + Base64::encode64("#{@member.email}:wrongpassword")
    https_get :new
    assert_false assigns(:current_member)
  end

  def test_new_initiate_chronussupport_google_oauth
    modify_const(:APP_CONFIG, google_oauth_client_id: "google-client-id", google_oauth_client_secret: "google-client-secret") do
      session[:chronussupport_step1_complete] = true
      current_organization_is @organization
      https_get :new, params: { chronussupport: "true"}
      assert_response :redirect
      assert_chronussupport_auth(true)
    end
  end

  def test_new_complete_chronussupport_google_oauth_when_domain_failure
    @member.update_attribute(:email, SUPERADMIN_EMAIL)
    @member.promote_as_admin!
    auth_obj = ProgramSpecificAuth.new(@organization.chronussupport_auth_config(true), "")
    auth_obj.uid = "sun@gmail.com"
    auth_obj.status = ProgramSpecificAuth::Status::NO_USER_EXISTENCE
    encoded_state = Base64.urlsafe_encode64("abcd")

    @request.session[OpenAuth::STATE_VARIABLE_IN_SESSION] = encoded_state
    @request.session["chronussupport_step1_complete"] = true
    @controller.expects(:get_open_auth_callback_url).returns("https://oauthcallback.chronus.com").once
    @controller.expects(:track_activity_for_ei).never
    Pendo.expects(:reset_pendo_guide_seen_data).never
    ProgramSpecificAuth.expects(:authenticate).once.returns(auth_obj)

    current_organization_is @organization
    https_get :new, params: { chronussupport: "true", code: "OAUTH_CODE", state: encoded_state, OpenAuth::CALLBACK_PARAM => OpenAuthUtils::Configurations::Google::CALLBACK_PARAM_VALUE}
    assert_redirected_to new_session_path(chronussupport: true, cjs_close_iab_refresh: 1, lst: ProgramSpecificAuth::StatusParams::AUTHENTICATION_FAILURE, org_id: @organization.id)
    assert_equal "Please ensure that you logged in using email of 'chronus.com' domain.", flash[:error]
    assert_chronussupport_auth(true)
    assert_false assigns(:current_member)
    assert_nil session[:chronussupport_step1_complete]
  end

  def test_new_complete_chronussupport_google_oauth
    @member.update_attribute(:email, SUPERADMIN_EMAIL)
    @member.promote_as_admin!
    auth_obj = ProgramSpecificAuth.new(@organization.chronussupport_auth_config(true), "")
    auth_obj.uid = "sun@chronus.com"
    auth_obj.status = ProgramSpecificAuth::Status::NO_USER_EXISTENCE
    encoded_state = Base64.urlsafe_encode64("abcd")

    @request.session[OpenAuth::STATE_VARIABLE_IN_SESSION] = encoded_state
    @request.session["chronussupport_step1_complete"] = true
    @controller.expects(:get_open_auth_callback_url).returns("https://oauthcallback.chronus.com").once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::LOGIN).once
    @controller.expects(:finished_chronus_ab_test_only_use_cookie).with(ProgramAbTest::Experiment::MOBILE_APP_LOGIN_WORKFLOW, true, true).once
    Pendo.expects(:reset_pendo_guide_seen_data)
    ProgramSpecificAuth.expects(:authenticate).once.returns(auth_obj)

    current_organization_is @organization
    https_get :new, params: { chronussupport: "true", code: "OAUTH_CODE", state: encoded_state, OpenAuth::CALLBACK_PARAM => OpenAuthUtils::Configurations::Google::CALLBACK_PARAM_VALUE}
    assert_redirected_to root_organization_path(cjs_close_iab_refresh: 1, lst: ProgramSpecificAuth::StatusParams::AUTHENTICATION_SUCCESS)
    assert_chronussupport_auth(true)
    assert_equal @member, assigns(:current_member)
    assert_nil session[:chronussupport_step1_complete]
  end

  def test_new_when_loggedin_organization_and_non_indigenous_non_remote_login
    soap_auth = create_soap_auth(false)
    member = members(:f_mentor)

    current_member_is member
    https_get :new, params: { auth_config_id: soap_auth.id}
    assert_response :success
    assert_equal soap_auth, assigns(:auth_config)
    assert_equal 1, assigns(:login_sections).size
    assert_equal_hash( { title: nil, description: nil, auth_configs: [soap_auth] }, assigns(:login_sections)[0])
    assert_equal member, assigns(:current_member)
  end

  def test_create_chronus_auth_with_remember_me
    chronus_auth = @organization.chronus_auth

    @controller.expects(:handle_remember_cookie!).with(true).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::LOGIN).once
    @controller.expects(:finished_chronus_ab_test_only_use_cookie).with(ProgramAbTest::Experiment::MOBILE_APP_LOGIN_WORKFLOW, true, true).once
    Pendo.expects(:reset_pendo_guide_seen_data)
    current_program_is @program
    https_post :create, xhr: true, params: { email: @member.email, password: "monkey", remember_me: 1, auth_config_id: chronus_auth.id}
    assert_xhr_redirect root_path(cjs_close_iab_refresh:1, lst: ProgramSpecificAuth::StatusParams::AUTHENTICATION_SUCCESS)
    assert_auth_config(chronus_auth)
    assert_equal @user, assigns(:current_user)
    assert_equal [], session[:closed_circles_in_publish_circle_widget_ids]
  end

  def test_create_chronus_auth_when_secure_domain
    chronus_auth = @organization.chronus_auth

    ActionDispatch::Flash::FlashHash.any_instance.expects(:clear).once
    @controller.expects(:handle_remember_cookie!).with(false).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::LOGIN).once
    @controller.expects(:finished_chronus_ab_test_only_use_cookie).with(ProgramAbTest::Experiment::MOBILE_APP_LOGIN_WORKFLOW, true, true).once
    Pendo.expects(:reset_pendo_guide_seen_data)
    mock_parent_session(@organization, "abcd")
    current_subdomain_is SECURE_SUBDOMAIN
    https_post :create, params: { email: @member.email, password: "monkey", auth_config_id: chronus_auth.id, SID_PARAM_NAME => "abcd"}
    assert_redirected_to root_path(cjs_close_iab_refresh: 1, lst: ProgramSpecificAuth::StatusParams::AUTHENTICATION_SUCCESS)
    assert_auth_config(chronus_auth)
    assert_equal @member, assigns(:current_member)
    assert_equal [], session[:closed_circles_in_publish_circle_widget_ids]
  end

  def test_create_chronus_auth_failure
    @organization.security_setting.update_attributes!(maximum_login_attempts: 1)
    chronus_auth = @organization.chronus_auth
    assert_equal 0, @member.failed_login_attempts

    @controller.expects(:track_activity_for_ei).never
    Pendo.expects(:reset_pendo_guide_seen_data).never
    current_organization_is @organization
    assert_no_emails do
      https_post :create, xhr: true, params: { email: @member.email, password: "invalid", auth_config_id: chronus_auth.id}
    end
    assert_response :success
    assert_equal "Login failed. Try again", assigns(:error_message)
    assert_false assigns(:current_member)
    assert_equal 1, @member.reload.failed_login_attempts
    assert_equal [], session[:closed_circles_in_publish_circle_widget_ids]
  end

  def test_create_chronus_auth_block_account_on_failure
    @organization.security_setting.update_attributes!(maximum_login_attempts: 1)
    @member.update_attributes!(failed_login_attempts: 1)

    @controller.expects(:track_activity_for_ei).never
    Pendo.expects(:reset_pendo_guide_seen_data).never
    current_program_is @program
    assert_emails do
      https_post :create, xhr: true, params: { email: @member.email, password: "invalid", auth_config_id: @organization.chronus_auth.id}
    end
    assert_response :success
    reactivate_link = ActionController::Base.helpers.link_to("display_string.Click_here".translate, reactivate_account_path(email: @member.email))
    assert_equal "Your account has been blocked due to multiple incorrect attempts to login. Please check your email to reactivate your account or #{reactivate_link} to resend the account reactivation email.", flash[:error]
    assert_false assigns(:current_member)
    assert_equal 2, @member.reload.failed_login_attempts
    assert_equal [], session[:closed_circles_in_publish_circle_widget_ids]
  end

  def test_create_chronus_auth_block_account_on_failure_and_not_notify_when_reactivation_email_disabled
    setup_admin_custom_term
    @organization.term_for(CustomizedTerm::TermType::PROGRAM_TERM).update_term(term: "Track")
    @organization.security_setting.update_attributes!(maximum_login_attempts: 1, reactivation_email_enabled: false)
    @member.update_attributes!(failed_login_attempts: 1)

    current_program_is @program
    Timecop.freeze(DateTime.now) do
      assert_no_emails do
        https_post :create, xhr: true, params: { email: @member.email, password: "invalid", auth_config_id: @organization.chronus_auth.id}
      end
      assert_response :success
      assert_equal "Your account has been blocked due to multiple incorrect attempts to login. Please contact the track super admin.", flash[:error]
      assert_false assigns(:current_member)
      assert_equal 2, @member.reload.failed_login_attempts
      assert_equal DateTime.now, @member.account_locked_at
      assert_equal [], session[:closed_circles_in_publish_circle_widget_ids]
    end
  end

  def test_create_chronus_auth_success_when_account_blocked
    @organization.security_setting.update_attributes!(maximum_login_attempts: 1, auto_reactivate_account: 3.0)
    @member.update_attributes!(failed_login_attempts: 3, account_locked_at: Time.now - 2.hours)

    current_program_is @program
    assert_no_emails do # Email sent already!
      # Should lock out on valid auth as well, as failed_login_attempts has already exceeded.
      https_post :create, xhr: true, params: { email: @member.email, password: "monkey", auth_config_id: @organization.chronus_auth.id}
    end
    assert_response :success
    reactivate_link = ActionController::Base.helpers.link_to("display_string.Click_here".translate, reactivate_account_path(email: @member.email))
    assert_equal "Your account has been blocked due to multiple incorrect attempts to login. Please check your email to reactivate your account or #{reactivate_link} to resend the account reactivation email.", flash[:error]
    assert_false assigns(:current_member)
    assert_equal 3, @member.reload.failed_login_attempts
    assert_equal [], session[:closed_circles_in_publish_circle_widget_ids]
  end

  def test_create_chronus_auth_when_password_expired
    @organization.security_setting.update_attributes!(password_expiration_frequency: 1)
    @member.update_attribute(:password_updated_at, Time.now - 10.days)

    @controller.expects(:track_activity_for_ei).never
    Pendo.expects(:reset_pendo_guide_seen_data).never
    current_organization_is @organization
    assert_emails do
      https_post :create, xhr: true, params: { email: @member.email, password: "monkey", auth_config_id: @organization.chronus_auth.id}
    end
    assert_response :success
    assert_equal "Your password has expired. Please check your email for instructions to reset your password.", flash[:error]
    assert_false assigns(:current_member)
    assert_equal [], session[:closed_circles_in_publish_circle_widget_ids]
  end

  def test_create_chronus_auth_skip_password_expired_for_mentor_admin
    @organization.security_setting.update_attributes!(password_expiration_frequency: 1)
    @member = members(:f_admin)
    @member.update_attributes!(password_updated_at: Time.now - 10.days, email: SUPERADMIN_EMAIL)
    current_member_is @member

    @controller.expects(:track_activity_for_ei).never
    Pendo.expects(:reset_pendo_guide_seen_data).never
    assert_no_emails do
      https_post :create, xhr: true, params: { email: @member.email, password: "monkey", auth_config_id: @organization.chronus_auth.id, chronussupport: "true" }
    end
    assert_response :success
    assert_nil flash[:error]
    assert_equal @member, assigns(:current_member)
    assert_nil session[:chronussupport_step1_complete]
    assert_equal [], session[:closed_circles_in_publish_circle_widget_ids]
  end


  def test_create_chronus_auth_sha2_migration
    crypted_password = Member.sha1_digest("chronus", @member.salt)
    @member.update_columns(encryption_type: Member::EncryptionType::SHA1, crypted_password: crypted_password)

    assert_no_difference "@member.versions.size" do
      # Encrypt existing SHA1 password to SHA2 and set the encryption_type to intermediate
      @member.migrate_pwd_to_intermediate
      assert_equal Member::EncryptionType::INTERMEDIATE, @member.encryption_type
      assert_equal @member.encrypt("chronus"), @member.crypted_password

      # Login to change (SHA1 + SHA2) to SHA2
      current_program_is @program
      https_post :create, xhr: true, params: { email: @member.email, password: "chronus", auth_config_id: @organization.chronus_auth.id}
      assert_xhr_redirect program_root_path(cjs_close_iab_refresh: 1, lst: ProgramSpecificAuth::StatusParams::AUTHENTICATION_SUCCESS)
      assert_equal @member, assigns(:current_member)
      assert_equal Member::EncryptionType::SHA2, @member.reload.encryption_type
      assert_equal @member.encrypt("chronus"), @member.crypted_password
      assert_equal [], session[:closed_circles_in_publish_circle_widget_ids]
    end
  end

  def test_create_chronus_auth_when_superadmin
    @member.update_attribute(:email, SUPERADMIN_EMAIL)
    @member.promote_as_admin!

    @controller.expects(:track_activity_for_ei).never
    Pendo.expects(:reset_pendo_guide_seen_data).never
    current_organization_is @organization
    https_post :create, xhr: true, params: { email: @member.email, password: "monkey", auth_config_id: @organization.chronus_auth.id}
    assert_xhr_redirect login_path(chronussupport: true)
    assert_false assigns(:current_member)
    assert session[:chronussupport_step1_complete]
    assert_equal [], session[:closed_circles_in_publish_circle_widget_ids]
  end

  def test_create_chronussupport_when_domain_failure
    current_program_is @program
    https_post :create, xhr: true, params: { email: @member.email, password: "monkey", chronussupport: "true"}
    assert_response :success
    assert_equal "Please ensure that you logged in using email of 'chronus.com' domain.", assigns(:error_message)
    assert_chronussupport_auth
    assert_false assigns(:current_member)
    assert_equal [], session[:closed_circles_in_publish_circle_widget_ids]
  end

  def test_create_chronussupport
    @member.update_attribute(:email, "sun@chronus.com")

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::LOGIN).once
    @controller.expects(:finished_chronus_ab_test_only_use_cookie).with(ProgramAbTest::Experiment::MOBILE_APP_LOGIN_WORKFLOW, true, true).once
    Pendo.expects(:reset_pendo_guide_seen_data)
    current_organization_is @organization
    https_post :create, xhr: true, params: { email: @member.email, password: "monkey", chronussupport: "true"}
    assert_response :success
    assert_chronussupport_auth
    assert_equal @member, assigns(:current_member)
    assert_nil session[:chronussupport_step1_complete]
    assert_equal [], session[:closed_circles_in_publish_circle_widget_ids]
  end

  def test_create_saml_auth
    saml_auth = create_saml_auth(@organization)
    @member.update_attribute(:email, "test100@colorado.edu")

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::LOGIN).once
    @controller.expects(:finished_chronus_ab_test_only_use_cookie).with(ProgramAbTest::Experiment::MOBILE_APP_LOGIN_WORKFLOW, true, true).once
    Pendo.expects(:reset_pendo_guide_seen_data)
    session[:prog_root] = @program.root
    current_organization_is @organization
    assert_difference "@member.login_identifiers.count" do
      https_post :create, params: { SAMLResponse: File.read("test/fixtures/files/saml_response")}
    end
    assert_redirected_to program_root_path(cjs_close_iab_refresh: 1, lst: ProgramSpecificAuth::StatusParams::AUTHENTICATION_SUCCESS)
    assert_auth_config(saml_auth)
    assert_equal @user, assigns(:current_user)
    assert_nil session[:prog_root]
    assert_equal @member.email, @member.login_identifiers.find_by(auth_config_id: saml_auth.id).identifier
    assert_equal [], session[:closed_circles_in_publish_circle_widget_ids]
  end

  def test_create_saml_auth_when_name_parser_and_import_options
    import_options = { "import_data" => { "name_identifier" => "Name", "attributes" => { "Member" => { "email" => "email" }, "ProfileAnswer" => { "1" => "username", "2" => "userId", "3" => "is_portal_user" } } } }
    saml_auth = create_saml_auth(@organization, { name_parser: true }, import_options)

    current_organization_is @organization
    https_post :create, params: { SAMLResponse: File.read("test/fixtures/files/saml_response_1")}
    assert_response :redirect
    assert_auth_config(saml_auth)
    assert_false assigns(:current_member)
    assert_equal_hash( { "Member" => { "email" => "aniketgajare@gmail.com" }, "ProfileAnswer" => { "1" => "aniketgajare@gmail.com", "2" => "005i0000000xuCt", "3" => "true" } }, session[:new_user_import_data][@organization.id])
    assert_equal [], session[:closed_circles_in_publish_circle_widget_ids]
  end

  def test_create_saml_auth_when_digest_algorithm_is_sha256
    saml_auth = create_saml_auth(@organization, {},
      "idp_cert_fingerprint" => "a5857a1d8341301e1c3e1d426157da460859da33",
      "xmlsec_privatekey" => "-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEA17fbELZbup+D/N4kaDwlik/Qrv0cZ4E3QJnAlHrEPTbJzjGp\nrR95OUjf9+lBJf2xE/CV96lm7jGLDPAhwLhltEP6jA/W+6TBcLLXgrb3F4848tB/\nFtU8CcBlHn4dh0/ppMhnWsp7OEXg+O4y2ts9VlPeoh+BnUQkwDPz0p7volax1HRI\nsouvoA2urC5Zr9PC6PqvvpjyrYmTy/5WyKGF0ZtlwqjBtzEeRy3T/b9zr3WZlZ32\nHpvpXewo38NA/0s8zhfK7fstmefvaBc3wjBdmRj14lzMbgN2DWDzDvg7365gNXib\n/UdScKTEqMIKc3bWedjRFbaq43cREPkVYY+LFQIDAQABAoIBAE66LNsGkqeje9oX\ngJYCDXlS88hJW8pyoCWVd3E49NGaY0A7Y79pEybS79pcaIhi8/NhBHpkespHjoXk\nRY0+Pu/xN0lSppUkZeypeHmeKMOSY6hKa3d7zvOIId9lC4XMpmqbMQ0zhJDe/+IZ\nnLm+9b3B0ii88uLgccErtLqTgsVtznZiFzAJl566XGZbwPyr4lLyYL7fGOUV7pE6\nn29nNJ5FmEvY2tOjZOZr5VdgmsSZEypi7lwDrDygMelQkrKBdMmGwrshCqD14Qf8\nZNvd1w9iOkGnaKvhf5JQfouKJR33Wi/EBILhdWeAxHZR7YLmmzNX8Ekca2OCBq3v\nyem/KQECgYEA/E2sc16ou/LbejlxmXfmtNoYJVGQnYL4nqgDyodeu/48arMjJvg4\nlYkt1khGqTdPaj1hf5n1bn0+N+6u+R5FjPlyOK0D6apkwK8PPyE2vz2VlJiE72qM\n55RIWnnQ5EfNYld9KNGVsIsx4o9hdZPXLdzeO7NioI02e/iAPqwXQDUCgYEA2uD1\nzC+NKIwPIQZazUWYbKp1q7MY/UpufzMqIJn73layi6Va2Tnn5UNPmrC4XdcLtSmM\nMa+tTlPc8ay+nKiSWzjFCTtsjdSpzMSpN5UbwIJUrMpUFORbkZ8tb82NZrR+iqq7\nolzCAVveFlG8gLMjxz8T7smmV8lMAu6+7NOkO2ECgYBw5CBhjt1ZG5Vw3vshfDDS\ngzOCnzhiAhRUiUEJAgE1hNBrvbPg3/gRkMvdsYFMfd8e3lAd1DmpMokAZeAMv6rH\nJWYiTegOSZvDS5E64hWpBFlFn+j7Z2WcyRCGyzLYsfgIJLVv6jdcQywS/6zP+1Kw\nxr75X46l4Amc9tgLMt1EcQKBgHon0waCA2X9xPPJeCPYE5mSCNoqumeigsi65WgM\niGUuPbdyMaHKj4GEb4kF19+HhSE2bufMBA0TANxgbIFCE2yV4mGkqJD/f0So/Ufo\nD/UAyAEnaoW+bNx42gLr1V7cnUMGxnF3E09u1iPeujWZxP4OVjGOmSelUKbSV/wU\nojQBAoGBAPhq48Wb4RyxnufYy+qIXMvqxyS3BVwyisPHITGyysghXMPfozoJtVVJ\ndq43RlnNURTYGuhYGfHsR3PPKYKrQTXs8OyqpSyruMxE1REMkfo+0H3EPgYpnClH\nRCR0x8kvDwWPpSQFGEiBGzbKDQGYpFOKadrkpHf+lrdYi92lY/uW\n-----END RSA PRIVATE KEY-----\n",
      "xmlsec_certificate" => "-----BEGIN CERTIFICATE-----\nMIIEqjCCA5KgAwIBAgIJANPoN49RcmJ9MA0GCSqGSIb3DQEBBQUAMIGUMQswCQYD\nVQQGEwJVUzEQMA4GA1UECBMHQXJpem9uYTETMBEGA1UEBxMKU2NvdHRzZGFsZTEV\nMBMGA1UEChMMQ2hyb251cyBDb3JwMQ8wDQYDVQQLEwZNZW50b3IxFjAUBgNVBAMU\nDSouY2hyb251cy5jb20xHjAcBgkqhkiG9w0BCQEWD29wc0BjaHJvbnVzLmNvbTAe\nFw0xNTAxMjAwOTE2MDlaFw0yNTAxMTcwOTE2MDlaMIGUMQswCQYDVQQGEwJVUzEQ\nMA4GA1UECBMHQXJpem9uYTETMBEGA1UEBxMKU2NvdHRzZGFsZTEVMBMGA1UEChMM\nQ2hyb251cyBDb3JwMQ8wDQYDVQQLEwZNZW50b3IxFjAUBgNVBAMUDSouY2hyb251\ncy5jb20xHjAcBgkqhkiG9w0BCQEWD29wc0BjaHJvbnVzLmNvbTCCASIwDQYJKoZI\nhvcNAQEBBQADggEPADCCAQoCggEBANe32xC2W7qfg/zeJGg8JYpP0K79HGeBN0CZ\nwJR6xD02yc4xqa0feTlI3/fpQSX9sRPwlfepZu4xiwzwIcC4ZbRD+owP1vukwXCy\n14K29xePOPLQfxbVPAnAZR5+HYdP6aTIZ1rKezhF4PjuMtrbPVZT3qIfgZ1EJMAz\n89Ke76JWsdR0SLKLr6ANrqwuWa/Twuj6r76Y8q2Jk8v+VsihhdGbZcKowbcxHkct\n0/2/c691mZWd9h6b6V3sKN/DQP9LPM4Xyu37LZnn72gXN8IwXZkY9eJczG4Ddg1g\n8w74O9+uYDV4m/1HUnCkxKjCCnN21nnY0RW2quN3ERD5FWGPixUCAwEAAaOB/DCB\n+TAdBgNVHQ4EFgQUwjrOcBBlsKfZKKd+ULhvVe5klscwgckGA1UdIwSBwTCBvoAU\nwjrOcBBlsKfZKKd+ULhvVe5klsehgZqkgZcwgZQxCzAJBgNVBAYTAlVTMRAwDgYD\nVQQIEwdBcml6b25hMRMwEQYDVQQHEwpTY290dHNkYWxlMRUwEwYDVQQKEwxDaHJv\nbnVzIENvcnAxDzANBgNVBAsTBk1lbnRvcjEWMBQGA1UEAxQNKi5jaHJvbnVzLmNv\nbTEeMBwGCSqGSIb3DQEJARYPb3BzQGNocm9udXMuY29tggkA0+g3j1FyYn0wDAYD\nVR0TBAUwAwEB/zANBgkqhkiG9w0BAQUFAAOCAQEA055jMeP+r+TuUvxyz+vp2K3O\nZthUTCfa14zQgENDkUXNpkP/ncPQCzyc5V8e+jxcEmT+WvAsw/5M7fE1il+9ABjT\n8KO7nxjOyWhRpBhZLzdOjldI+cEZeVkg4k0HGoYdUP40rGuhp1xRZXEnjFKjuivb\npAX2gVXt2Kj2hWnrfZOc6bCQ0wmvkYtGaOXsdF32ZJIzO3c3Aod4/zh0aBW7qp1b\nPcmozRp3QbxOxVShfRp6ImWJheWiY0PBOmXP0qs/awZ8xYe38nXCqc7C2rG02Nys\noRl3rt2WIsEX3JifIH3l5HYZnUuwWyA3+bpiPcz8d4bOmn5C/jPntku/Ug+zEQ==\n-----END CERTIFICATE-----\n",
      "friendly_name" => nil
    )
    @member.login_identifiers.create!(auth_config: saml_auth, identifier: "81768")

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::LOGIN).once
    @controller.expects(:finished_chronus_ab_test_only_use_cookie).with(ProgramAbTest::Experiment::MOBILE_APP_LOGIN_WORKFLOW, true, true).once
    Pendo.expects(:reset_pendo_guide_seen_data)
    current_program_is @program
    https_post :create, params: { SAMLResponse: File.read("test/fixtures/files/saml_response_2")}
    assert_auth_config(saml_auth)
    assert_equal @user, assigns(:current_user)
    assert_equal [], session[:closed_circles_in_publish_circle_widget_ids]
  end

  def test_create_soap_auth
    soap_auth = create_soap_auth(false)
    @member.login_identifiers.create!(auth_config: soap_auth, identifier: "uid")
    auth_obj = ProgramSpecificAuth.new(soap_auth, "")
    auth_obj.uid = "uid"
    auth_obj.status = ProgramSpecificAuth::Status::AUTHENTICATION_SUCCESS
    auth_obj.member = @member

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::LOGIN).once
    @controller.expects(:finished_chronus_ab_test_only_use_cookie).with(ProgramAbTest::Experiment::MOBILE_APP_LOGIN_WORKFLOW, true, true).once
    Pendo.expects(:reset_pendo_guide_seen_data)
    ProgramSpecificAuth.expects(:authenticate).returns(auth_obj)
    current_program_is @program
    https_post :create, xhr: true, params: { username: "user", password: "correct", auth_config_id: soap_auth.id}
    assert_xhr_redirect program_root_path(cjs_close_iab_refresh:1, lst: ProgramSpecificAuth::StatusParams::AUTHENTICATION_SUCCESS)
    assert_equal @member, assigns(:current_member)
    assert_equal [], session[:closed_circles_in_publish_circle_widget_ids]
  end

  def test_create_token_based_soap_auth
    soap_auth = create_soap_auth
    auth_obj = ProgramSpecificAuth.new(soap_auth, "")
    auth_obj.uid = "uid"
    auth_obj.nftoken = "67890"
    auth_obj.status = ProgramSpecificAuth::Status::AUTHENTICATION_SUCCESS
    auth_obj.member = @member

    ProgramSpecificAuth.expects(:authenticate).returns(auth_obj)
    current_program_is @program
    https_post :create, xhr: true, params: { username: "user", password: "correct", auth_config_id: soap_auth.id}
    assert_xhr_redirect "https://soap.chronus.com/settoken&nftoken=67890&nfredirect=#{new_session_url(cjs_close_iab_refresh: 1)}"
    assert_false assigns(:current_member)
    assert_equal [], session[:closed_circles_in_publish_circle_widget_ids]
  end

  def test_destroy
    current_user_is @user
    get :destroy
    assert_redirected_to root_path
    assert_false assigns(:current_member)
  end

  def test_destroy_when_logout_path
    @organization.update_attribute(:logout_path, "https://chronus.com")

    current_member_is @member
    get :destroy
    assert_redirected_to "https://chronus.com"
    assert_false assigns(:current_member)
  end

  def test_destroy_when_goto_param
    current_user_is @user
    get :destroy, params: { goto: "login"}
    assert_redirected_to login_path(src: "excp")
    assert_false assigns(:current_member)
  end

  def test_destroy_when_demo_env
    DelayedEsDocument.stubs(:es_index_present?).returns(true)
    Rails.stubs(:env).returns(ActiveSupport::StringInquirer.new("demo"))
    current_user_is @user
    get :destroy
    assert_redirected_to login_path(mode:SessionsController::LoginMode::STRICT)
    assert_false assigns(:current_member)
  end

  def test_destroy_clears_cookies
    cookies[CookiesConstants::MENTORING_AREA_VISITED] = 1
    cookies[AutoLogout::Cookie::SESSION_ACTIVE] = 1000
    cookies["#{GroupsController::OVERDUE_SURVEY_POPUP_COOKIE_FORMAT}_12"] = { value: true, expires: GroupsController::OVERDUE_SURVEY_POPUP_COOKIE_EXPIRY_TIME }
    cookies["#{GroupsController::OVERDUE_SURVEY_POPUP_COOKIE_FORMAT}_13"] = { value: true, expires: GroupsController::OVERDUE_SURVEY_POPUP_COOKIE_EXPIRY_TIME }

    current_user_is @user
    get :destroy
    assert_redirected_to root_path
    assert_false assigns(:current_member)
    assert_nil cookies[CookiesConstants::MENTORING_AREA_VISITED]
    assert_nil cookies[AutoLogout::Cookie::SESSION_ACTIVE]
    assert_nil cookies["#{GroupsController::OVERDUE_SURVEY_POPUP_COOKIE_FORMAT}_12"]
    assert_nil cookies["#{GroupsController::OVERDUE_SURVEY_POPUP_COOKIE_FORMAT}_13"]
  end

  def test_destroy_when_no_authenticity_token
    initial_forgery_protection_val = ActionController::Base.allow_forgery_protection

    ActionController::Base.allow_forgery_protection = true
    assert_raise ActionController::InvalidAuthenticityToken do
      post :destroy
    end
    ActionController::Base.allow_forgery_protection = initial_forgery_protection_val
  end

  def test_destroy_cookie_auth_slo
    create_cookie_auth

    cookies[:enc_constitid] = { value: EncryptionEngine::DES.new("DES", "TESTiInt").encrypt("Tes1t") }
    current_member_is @member
    get :destroy
    assert_redirected_to "https://cookie.chronus.com/logout"
    assert_false assigns(:current_member)
  end

  def test_destroy_token_based_soap_auth_slo
    soap_auth = create_soap_auth

    SOAPAuth.expects(:logout).with(soap_auth.get_options, "nftoken" => "12345").once
    session[:nftoken] = "12345"
    current_member_is @member
    get :destroy
    assert_redirected_to root_path
    assert_false assigns(:current_member)
  end

  def test_destroy_saml_auth_slo
    create_saml_auth(@organization, slo: true)

    session[:name_qualifier] = "http://idp.ssocircle.com"
    session[:session_index] = "s2092a7c9ee2ae3b37694e7c1f211d69dfc84af201"
    session[:name_id] = "TZmcE91NohanrJdihOMFqOTDeh6P"
    session[:slo_enabled] = true

    current_user_is @user
    get :destroy
    assert_response :redirect
    assert_false assigns(:current_member)
    assert_nil session[:name_qualifier]
    assert_nil session[:session_index]
    assert_nil session[:name_id]
    assert_nil session[:slo_enabled]
  end

  def test_saml_slo_when_response
    @member.mobile_devices.create!(mobile_auth_token: "test", device_token: "token", platform: MobileDevice::Platform::ANDROID)
    create_saml_auth(@organization, slo: true)

    @controller.stubs(:mobile_platform).returns(MobileDevice::Platform::ANDROID)
    cookie = ActionDispatch::Cookies::CookieJar.build(@request, @request.cookies)
    cookie.signed[MobileV2Constants::MOBILE_V2_AUTH_TOKEN] = 'test'
    cookies[MobileV2Constants::MOBILE_V2_AUTH_TOKEN] = cookie[MobileV2Constants::MOBILE_V2_AUTH_TOKEN]
    session[:name_qualifier] = "http://idp.ssocircle.com"
    session[:session_index] = "s2092a7c9ee2ae3b37694e7c1f211d69dfc84af201"
    session[:name_id] = "TZmcE91NohanrJdihOMFqOTDeh6P"
    session[:slo_enabled] = true

    current_user_is @user
    assert_difference "@member.mobile_devices.count", -1 do
      get :saml_slo, params: { SAMLResponse: File.read("test/fixtures/files/saml_slo_response")}
    end
    assert_redirected_to root_path(cjs_close_iab_refresh:1)
    assert_false assigns(:current_member)
    assert_nil session[:name_qualifier]
    assert_nil session[:session_index]
    assert_nil session[:name_id]
    assert_nil session[:slo_enabled]
    assert_nil cookies[MobileV2Constants::MOBILE_V2_AUTH_TOKEN]
  end

  def test_saml_slo_when_partial_response
    create_saml_auth(@organization, slo: true)

    session[:name_qualifier] = "http://idp.ssocircle.com"
    session[:session_index] = "s2092a7c9ee2ae3b37694e7c1f211d69dfc84af201"
    session[:name_id] = "TZmcE91NohanrJdihOMFqOTDeh6P"
    session[:slo_enabled] = true

    current_user_is @user
    get :saml_slo, params: { SAMLResponse: File.read("test/fixtures/files/saml_slo_response_status_partial_logout")}
    assert_redirected_to root_path
    assert_equal @user, assigns(:current_user)
    assert_not_nil session[:name_qualifier]
    assert_not_nil session[:session_index]
    assert_not_nil session[:name_id]
    assert_not_nil session[:slo_enabled]
  end

  def test_destroy_dissociate_mobile_device
    @controller.stubs(:mobile_platform).returns(MobileDevice::Platform::ANDROID)
    @member.mobile_devices.create!(mobile_auth_token: "test", device_token: "token", platform: MobileDevice::Platform::ANDROID)

    Timecop.freeze(DateTime.now) do
      cookie = ActionDispatch::Cookies::CookieJar.build(@request, @request.cookies)
      cookie.signed[MobileV2Constants::MOBILE_V2_AUTH_TOKEN] = "test"
      cookies[MobileV2Constants::MOBILE_V2_AUTH_TOKEN] = cookie[MobileV2Constants::MOBILE_V2_AUTH_TOKEN]
      session[:mobile_device] = { token: "token", refreshed_at: DateTime.now.utc }

      current_member_is @member
      assert_difference "@member.mobile_devices.count", -1 do
        get :destroy
      end
      assert_false assigns(:current_member)
      assert_nil session[:mobile_device]
      assert_nil cookies[MobileV2Constants::MOBILE_V2_AUTH_TOKEN]
    end
  end

  def test_refresh_when_unloggedin
    current_program_is @program
    get :refresh
    assert_redirected_to new_session_path
    assert_nil cookies["session_active"]
  end

  def test_refresh_when_loggedin
    Timecop.freeze(Time.now) do
      current_user_is @user
      get :refresh
      assert_response :success
      assert_blank @response.body
      assert_equal (Time.now + (@organization.security_setting.login_expiry_period.minutes - 1.minute).seconds).to_i, cookies["session_active"].to_i
    end
  end

  def test_zendesk_permission_denied
    current_user_is @user
    assert_permission_denied do
      get :zendesk
    end
  end

  def test_zendesk
    member = members(:f_admin)

    Timecop.freeze(Time.now) do
      current_member_is member
      get :zendesk, params: {return_to: "https://www.test.com"}
      assert_response :redirect
      uri_params = CGI.parse URI.parse(@response.location).query
      jwt_params = JWT.decode(uri_params["jwt"][0], APP_CONFIG[:zendesk_shared_secret].to_s)[0]
      assert_equal member.email, jwt_params["email"]
      assert_equal member.name(name_only: true), jwt_params["name"]
      assert_equal Time.now.to_i, jwt_params["iat"]
      assert jwt_params["jti"].present?
      assert_equal "https://www.test.com", uri_params["return_to"][0]
      assert_equal member.organization.name.tr(" ", "_"), jwt_params["tags"]
    end
  end

  def test_register_device_token_when_unloggedin
    session[:mobile_device] = nil
    current_organization_is @organization
    post :register_device_token, xhr: true, params: { format: :js}
    assert_response 401
    assert_nil session[:mobile_device]
  end

  def test_register_device_token_when_no_token
    assert_blank @member.mobile_devices

    session[:mobile_device] = nil
    current_member_is @member
    Timecop.freeze(DateTime.now) do
      assert_no_difference "MobileDevice.count" do
        post :register_device_token, xhr: true, params: { format: :js}
        assert_response :success
        assert_nil session[:mobile_device][:token]
        assert_equal DateTime.now, session[:mobile_device][:refreshed_at]
      end
    end
  end

  def test_register_device_token
    assert_blank @member.mobile_devices

    cookie = ActionDispatch::Cookies::CookieJar.build(@request, @request.cookies)
    cookie.signed[MobileV2Constants::MOBILE_V2_AUTH_TOKEN] = "test"
    cookies[MobileV2Constants::MOBILE_V2_AUTH_TOKEN] = cookie[MobileV2Constants::MOBILE_V2_AUTH_TOKEN]
    session[:mobile_device] = nil

    current_member_is @member
    Timecop.freeze(DateTime.now) do
      assert_difference "MobileDevice.count" do
        post :register_device_token, xhr: true, params: { format: :js, device_token: "token"}
        assert_response :success
        assert_equal "token", session[:mobile_device][:token]
        assert_equal "token", @member.reload.mobile_devices.first.device_token
        assert_equal "test", @member.mobile_devices.first.mobile_auth_token
        assert_equal DateTime.now, session[:mobile_device][:refreshed_at]
      end
    end
  end

  def test_login_when_back_link
    @controller.expects(:back_url).at_least(0).returns("https://chronus.com")
    current_program_is @program
    https_post :create, xhr: true, params: { email: @member.email, password: "monkey", auth_config_id: @organization.chronus_auth.id}
    assert_xhr_redirect "https://chronus.com"
    assert_equal [], session[:closed_circles_in_publish_circle_widget_ids]
  end

  def test_login_when_mobile_app
    current_program_is @program
    https_post :create, params: { email: @member.email, password: "monkey", auth_config_id: @organization.chronus_auth.id}
    assert_redirected_to root_path(cjs_close_iab_refresh:1, lst: ProgramSpecificAuth::StatusParams::AUTHENTICATION_SUCCESS)
    assert_equal @user, assigns(:current_user)
    assert_equal true, session[:set_mobile_auth_cookie]
    assert_equal [], session[:closed_circles_in_publish_circle_widget_ids]
  end

  def test_login_when_not_mobile_app
    @controller.stubs(:is_mobile_app?).returns(false)
    current_program_is @program
    https_post :create, params: { email: @member.email, password: "monkey", auth_config_id: @organization.chronus_auth.id}
    assert_redirected_to root_path(lst: ProgramSpecificAuth::StatusParams::AUTHENTICATION_SUCCESS)
    assert_equal @user, assigns(:current_user)
    assert_nil session[:set_mobile_auth_cookie]
    assert_equal [], session[:closed_circles_in_publish_circle_widget_ids]
  end

  def test_login_when_suspended_member
    @member.suspend!(members(:f_admin), "Reason")

    @controller.expects(:track_activity_for_ei).never
    Pendo.expects(:reset_pendo_guide_seen_data).never
    current_organization_is @organization
    https_post :create, xhr: true, params: { email: @member.email, password: "monkey", auth_config_id: @organization.chronus_auth.id}
    assert_xhr_redirect program_root_path(lst: ProgramSpecificAuth::StatusParams::MEMBER_SUSPENSION, org_id: @organization.id)
    assert_equal "You do not have access to this program. Please contact the administrator for more information.", flash[:error]
    assert_false assigns(:current_member)
    assert_equal [], session[:closed_circles_in_publish_circle_widget_ids]
  end

  def test_login_when_permission_denied
    saml_auth = create_saml_auth(@organization)
    auth_obj = ProgramSpecificAuth.new(saml_auth, "")
    auth_obj.status = ProgramSpecificAuth::Status::PERMISSION_DENIED
    auth_obj.has_data_validation = true
    auth_obj.is_data_valid = false
    auth_obj.permission_denied_message = "Not a valid member"

    @controller.expects(:track_activity_for_ei).never
    Pendo.expects(:reset_pendo_guide_seen_data).never
    ProgramSpecificAuth.expects(:authenticate).returns(auth_obj)
    current_organization_is @organization
    https_post :create, params: { SAMLResponse: File.read("test/fixtures/files/saml_response")}
    assert_redirected_to program_root_path(cjs_close_iab_refresh:1, lst: ProgramSpecificAuth::StatusParams::PERMISSION_DENIED, org_id: @organization.id)
    assert_equal "Not a valid member", flash[:error]
    assert_auth_config saml_auth
    assert_false assigns(:current_member)
    assert_equal [], session[:closed_circles_in_publish_circle_widget_ids]
  end

  def test_login_when_signup_code
    session[:signup_code] = { @program.root => { code: "12345", roles: [RoleConstants::STUDENT_NAME] } }
    current_program_is @program
    perform_login_and_assert_loggedin(@user, :new_membership_request_path, root: @program.root, signup_code: "12345", roles: [RoleConstants::STUDENT_NAME])
  end

  def test_login_when_signup_code_and_user_suspended
    @user.suspend_from_program!(users(:f_admin), "Reason")

    session[:signup_code] = { @program.root => { code: "12345", roles: [RoleConstants::STUDENT_NAME] } }
    current_program_is @program
    perform_login_and_assert_loggedin(@member, :new_membership_request_path, root: @program.root, signup_code: "12345", roles: [RoleConstants::STUDENT_NAME])
  end

  def test_login_when_signup_roles
    session[:signup_roles] = { @program.root => [RoleConstants::STUDENT_NAME] }
    current_program_is @program
    redirect_path = new_membership_request_path(root: @program.root, lst: ProgramSpecificAuth::StatusParams::AUTHENTICATION_SUCCESS, roles: [RoleConstants::STUDENT_NAME], cjs_close_iab_refresh:1)
    perform_login_and_assert_loggedin(@user, :new_membership_request_path, root: @program.root, roles: [RoleConstants::STUDENT_NAME])
  end

  def test_login_when_signup_roles_and_user_suspended
    @user.suspend_from_program!(users(:f_admin), "Reason")

    session[:signup_roles] = { @program.root => [RoleConstants::STUDENT_NAME] }
    current_program_is @program
    perform_login_and_assert_loggedin(@member, :new_membership_request_path, root: @program.root, roles: [RoleConstants::STUDENT_NAME])
  end

  def test_login_when_signup_roles_and_organization_level
    session[:signup_roles] = { @program.root => [RoleConstants::STUDENT_NAME] }
    current_organization_is @organization
    perform_login_and_assert_loggedin(@member, :new_membership_request_path, root: @program.root, roles: [RoleConstants::STUDENT_NAME])
  end

  def test_login_when_signup_roles_and_program_mismatch
    session[:signup_roles] = { programs(:nwen).root => [RoleConstants::STUDENT_NAME] }
    current_program_is @program
    perform_login_and_assert_loggedin(@user, :program_root_path, root: @program.root)
  end

  def test_login_when_invite_code
    session[:invite_code] = "12345"
    current_program_is @program
    perform_login_and_assert_loggedin(@user, :new_registration_path, root: @program.root, invite_code: "12345")
  end

  def test_login_when_reset_code
    session[:reset_code] = "12345"
    current_program_is @program
    perform_login_and_assert_loggedin(@user, :edit_member_path, id: @member.id, root: @program.root, ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
    assert_equal "Welcome to #{@program.name}. Please complete your online profile to proceed.", flash[:notice]
    assert_nil session[:reset_code]
  end

  def test_login_when_user_suspended_and_program_not_allows_join
    @user.suspend_from_program!(users(:f_admin), "Reason")

    Program.any_instance.stubs(:allow_join_now?).returns(false)
    current_program_is @program
    perform_login_and_assert_loggedin(@member, :root_path, root: @program.root)
    assert_equal "Your access to the program may have been temporarily revoked. Please contact the administrators <a href=\"https://test.host/p/#{@program.root}/contact_admin?cjs_close_iab_refresh=1\" class=\"no-waves\">here</a> for further assistance.", flash[:error]
  end

  def test_login_new_external_user
    current_program_is @program
    perform_external_login_and_assert_new_user(:new_membership_request_path, root: @program.root)
  end

  def test_login_new_external_user_when_organization_level
    current_organization_is @organization
    perform_external_login_and_assert_new_user(:root_path, {})
  end

  def test_login_new_external_user_when_program_not_allows_join
    Program.any_instance.stubs(:allow_join_now?).returns(false)
    current_program_is @program
    perform_external_login_and_assert_new_user(:root_path, root: @program.root)
    assert_equal "You are not a member of this program.", flash[:notice]
  end

  def test_login_new_external_user_when_signup_roles
    session[:signup_roles] = { @program.root => [RoleConstants::STUDENT_NAME] }
    current_organization_is @organization
    perform_external_login_and_assert_new_user(:new_membership_request_path, root: @program.root, roles: [RoleConstants::STUDENT_NAME])
  end

  def test_login_new_external_user_when_invite_code
    session[:invite_code] = "12345"
    current_program_is @program
    perform_external_login_and_assert_new_user(:new_registration_path, root: @program.root, invite_code: "12345")
  end

  def test_login_new_external_user_when_reset_code
    session[:reset_code] = "12345"
    current_organization_is @organization
    perform_external_login_and_assert_new_user(:new_user_followup_users_path, reset_code: "12345")
  end

  def test_link_to_login
    member = members(:f_mentor)

    current_member_is member
    assert_difference "member.login_identifiers.count" do
      perform_external_login
    end
    assert_redirected_to account_settings_path
    assert_equal "Successfully authenticated.", flash[:notice]
    assert_equal "aniketgajare@gmail.com", member.login_identifiers.find_by(auth_config_id: @saml_auth.id).identifier
    assert_equal member, assigns(:current_member)
  end

  def test_link_to_login_when_member_mismatch
    member = members(:f_mentor)

    current_member_is member
    assert_no_difference "member.login_identifiers.count" do
      perform_external_login do
        @saml_auth.login_identifiers.create!(member: members(:f_student), identifier: "aniketgajare@gmail.com")
      end
    end
    assert_redirected_to account_settings_path
    assert_equal "The '#{@saml_auth.title}' user account is already tied to another user in the program.", flash[:error]
    assert_equal member, assigns(:current_member)
  end

  def test_link_to_login_when_fails
    member = members(:f_mentor)

    current_member_is member
    assert_no_difference "member.login_identifiers.count" do
      perform_external_login do
        auth_obj = ProgramSpecificAuth.new(@saml_auth, nil)
        auth_obj.status = ProgramSpecificAuth::Status::AUTHENTICATION_FAILURE
        ProgramSpecificAuth.stubs(:authenticate).returns(auth_obj)
      end
    end
    assert_redirected_to account_settings_path
    assert_equal "Login failed. Try again", flash[:error]
    assert_equal member, assigns(:current_member)
  end

  def test_oauth_callback_invalid
    current_subdomain_is SECURE_SUBDOMAIN
    https_get :oauth_callback
    assert_response :success
    assert_equal "", @response.body
  end

  def test_oauth_callback
    encoded_state = Base64.urlsafe_encode64("abcd@@!")
    callback_params = {
      controller: SessionsController.controller_name,
      action: "new",
      OpenAuth::CALLBACK_PARAM => OpenAuthUtils::Configurations::Linkedin::CALLBACK_PARAM_VALUE
    }

    mock_parent_session(@organization, "abcd@@!", OpenAuth::STATE_VARIABLE_IN_SESSION.to_s => encoded_state, "oauth_callback_params" => callback_params)
    current_subdomain_is SECURE_SUBDOMAIN
    https_get :oauth_callback, params: { state: CGI.escape(encoded_state), code: "12345"}
    assert_redirected_to "https://#{@organization.url}/session/new?code=12345&#{OpenAuth::CALLBACK_PARAM}=#{OpenAuthUtils::Configurations::Linkedin::CALLBACK_PARAM_VALUE}&state=#{CGI.escape(CGI.escape(encoded_state))}"
  end

  def test_oauth_callback_when_browsertab
    encoded_state = Base64.urlsafe_encode64("abcd")
    callback_params = {
      controller: SessionsController.controller_name,
      action: "new",
      browsertab: true,
      OpenAuth::CALLBACK_PARAM => OpenAuthUtils::Configurations::Linkedin::CALLBACK_PARAM_VALUE
    }

    mock_parent_session(@organization, "abcd", OpenAuth::STATE_VARIABLE_IN_SESSION.to_s => encoded_state, "oauth_callback_params" => callback_params)
    current_subdomain_is SECURE_SUBDOMAIN
    https_get :oauth_callback, params: { state: encoded_state, code: "12345"}
    assert_response :success
    assert_equal "chronustd://https://#{@organization.url}/session/new?code=12345&#{OpenAuth::CALLBACK_PARAM}=#{OpenAuthUtils::Configurations::Linkedin::CALLBACK_PARAM_VALUE}&state=#{CGI.escape(encoded_state)}", assigns(:redirect_url)
  end

  private

  def create_openssl_auth
    auth_config = @organization.auth_configs.new(auth_type: AuthConfig::Type::OPENSSL)
    auth_config.set_options!("url" => "https://openssl.chronus.com", "private_key" => "abc")
    auth_config
  end

  def create_bbnc_auth
    auth_config = @organization.auth_configs.new(auth_type: AuthConfig::Type::BBNC)
    auth_config.set_options!("url" => "https://bbnc.chronus.com", "private_key" => "abc")
    auth_config
  end

  def create_cookie_auth
    auth_config = @organization.auth_configs.new(auth_type: AuthConfig::Type::Cookie)
    auth_config.set_options!(
      login_url: "https://cookie.chronus.com",
      logout_url: "https://cookie.chronus.com/logout",
      organization: "spe",
      "encryption" => {
        "class" => "EncryptionEngine::DES",
        "options" => {
          "mode" => "DES",
          "key" => "TESTiInt",
          "iv" => nil
        }
      }
    )
    auth_config
  end

  def create_soap_auth(token_based = true)
    auth_config = @organization.auth_configs.new(auth_type: AuthConfig::Type::SOAP)
    options = { "empty_guid" => "00000000-0000-0000-0000-000000000000" }
    if token_based
      options.merge!(
        "get_token_url" => "https://soap.chronus.com",
        "set_token_url" => "https://soap.chronus.com/settoken"
      )
    end

    auth_config.set_options!(options)
    auth_config
  end

  def assert_auth_config(auth_config)
    if auth_config.nil?
      assert_nil assigns(:auth_config)
      assert_nil session[:auth_config_id]
    else
      assert_equal auth_config, assigns(:auth_config)
      assert_equal auth_config.id, session[:auth_config_id][@organization.id]
    end
  end

  def assert_chronussupport_auth(non_indigenous = false)
    auth_method = non_indigenous ? :google_oauth? : :indigenous?

    assert assigns(:auth_config).send(auth_method)
    assert assigns(:auth_config).readonly?
    assert assigns(:chronussupport)
    assert_equal @organization, assigns(:auth_config).organization
  end

  def perform_login_and_assert_loggedin(user_or_member, redirect_url, url_params)
    redirect_path = send(redirect_url, { lst: ProgramSpecificAuth::StatusParams::AUTHENTICATION_SUCCESS, cjs_close_iab_refresh: 1 }.merge!(url_params) )
    post_params = { email: @member.email, password: "monkey", auth_config_id: @organization.chronus_auth.id }

    random = [1, 2].sample
    if random == 1
      https_post :create, xhr: true, params: post_params
      assert_xhr_redirect redirect_path
    else
      https_post :create, params: post_params
      assert_redirected_to redirect_path
    end

    if user_or_member.is_a?(User)
      assert_equal @user, assigns(:current_user)
    else
      assert_equal @member, assigns(:current_member)
      assert_nil assigns(:current_user)
    end
  end

  def perform_external_login_and_assert_new_user(redirect_url, url_params)
    @controller.expects(:track_activity_for_ei).never
    Pendo.expects(:reset_pendo_guide_seen_data).never
    perform_external_login
    assert_redirected_to send(redirect_url, { lst: ProgramSpecificAuth::StatusParams::NO_USER_EXISTENCE, cjs_close_iab_refresh: 1, org_id: @organization.id }.merge!(url_params))
    assert_false assigns(:current_member)
    assert_equal_hash( { @organization.id => "aniketgajare@gmail.com", auth_config_id: @saml_auth.id, is_uid_email: true }, session[:new_custom_auth_user])
  end

  def perform_external_login
    @saml_auth = create_saml_auth(@organization, name_parser: true)
    yield if block_given?
    https_post :create, params: { SAMLResponse: File.read("test/fixtures/files/saml_response_1")}
  end
end