require_relative '../../test_helper'

class MobileV2::HomeControllerTest < ActionController::TestCase

  def setup
    super
    MobileV2::HomeController.any_instance.stubs(:is_mobile_app?).returns(true)
    @redirect_url = "annauniv." + DEFAULT_DOMAIN_NAME
    @org_set_cookie = MobileV2Constants::ORGANIZATION_SETUP_COOKIE
  end

  def test_verify_organization
    @controller.expects(:handle_secondary_url).never
    get :verify_organization
    assert_response :success
  end

  def test_verify_organization_with_cookie
    request.cookies[@org_set_cookie] = @redirect_url
    get :verify_organization
    assert_response :redirect
    assert_equal cookies[@org_set_cookie], @redirect_url
    assert_match /#{@redirect_url}\?last_visited_program\=true/, response.body
  end

  def test_verify_organization_for_edit
    request.cookies[@org_set_cookie] = @redirect_url
    get :verify_organization, params: { :edit => true}
    assert_response :success
    assert assigns(:change_program_url)
    assert_nil cookies[:@org_set_cookie]
  end

  def test_verify_organization_for_org_url
    get :verify_organization, params: { open_url: "iitm.realizegoal.com/p/cs/manage"}
    assert_response :success
    assert_equal "iitm.realizegoal.com/p/cs/manage?cjs_from_select_org=true", assigns[:redirect_url]
  end

  def test_validate_organization_success
    current_program_is :pbe
    @controller.expects(:handle_secondary_url).never
    get :validate_organization
    assert_response :success
    program = programs(:pbe)
    hosts = program.organization.hostnames
    response_body = JSON.parse(@response.body)
    assert_match response_body["status"], "ok"
    assert_equal hosts, response_body["default_hosts"]
  end

  def test_validate_organization_failure
    get :validate_organization
    assert_response :success
    response_body = JSON.parse(@response.body)
    assert_nil response_body["status"]
    assert_nil response_body["default_hosts"]
    assert_false response_body["valid_program"]
  end

  def test_permission_denied_not_in_mobile_app
    MobileV2::HomeController.any_instance.stubs(:is_mobile_app?).returns(false)
    assert_permission_denied{ get :verify_organization }
    assert_permission_denied{ get :validate_organization }
  end

  def test_fakedoor
    @controller.expects(:handle_secondary_url).never
    get :fakedoor
    assert_response :success
    assert_equal true, assigns[:disable_footer]
  end

  def test_fakedoor_permission_denied_not_in_mobile_app
    MobileV2::HomeController.any_instance.stubs(:is_mobile_app?).returns(false)
    assert_permission_denied{ get :fakedoor }
  end

  def test_global_member_search
    request.cookies[:uniq_token] = "uniq_token"
    GlobalMemberSearch.expects(:search).with("iitm_admin@chronus.com", "uniq_token")
    post :global_member_search, params: { email: "iitm_admin@chronus.com" }
  end

  def test_validate_member
    request.cookies[:uniq_token] = "uniq_token"
    GlobalMemberSearch.expects(:configure_login_token_and_email).with(Member.where(email: "robert@example.com"), "uniq_token").once
    post :validate_member, params: { email: "robert@example.com", global_member_search_api_key: "somevalue", uniq_token: "uniq_token", format: :json }
    assert_response :success
    response_body = JSON.parse(@response.body)
    assert_equal "ok", response_body["status"]

    assert_permission_denied do
      post :validate_member, params: { email: "robert@example.com", global_member_search_api_key: "invalid_key", uniq_token: "uniq_token", format: :json }
    end

    post :validate_member, params: { email: "invalid_user@example.com", global_member_search_api_key: "somevalue", uniq_token: "uniq_token", format: :json }
    assert_empty @response.body
  end

  def test_experiment_in_verify_organization
    experiment = Experiments::MobileAppLoginWorkflow.new(nil)
    @controller.stubs(:chronus_ab_test_only_use_cookie).with(ProgramAbTest::Experiment::MOBILE_APP_LOGIN_WORKFLOW, true, true).returns(experiment)
    get :verify_organization, params: { edit: true }
    assert_equal experiment, assigns(:experiment)

    get :verify_organization
    assert_equal experiment, assigns(:experiment)

    get :verify_organization, params: { show_program_form: true }
    assert_equal experiment, assigns(:experiment)
    assert assigns(:show_program_form)
  end

  def test_experiment_in_verify_organization_nil
    get :verify_organization, params: { open_url: "iitm.realizegoal.com/p/cs/manage" }
    assert_nil assigns(:experiment)
    assert_false assigns(:show_program_form)

    @redirect_url = "annauniv." + DEFAULT_DOMAIN_NAME
    request.cookies[@org_set_cookie] = @redirect_url
    get :verify_organization
    assert_nil assigns(:experiment)
  end

  def test_uniq_token
    request.cookies[:uniq_token] = "uniq_token_1"
    get :verify_organization
    assert_match "uniq_token_1", assigns(:uniq_token)

    request.cookies[:uniq_token] = "uniq_token_1"
    GlobalMemberSearch.expects(:search).with("iitm_admin@chronus.com", "uniq_token_1")
    post :global_member_search, params: { email: "iitm_admin@chronus.com" }
    assert_match "uniq_token_1", assigns(:uniq_token)
  end

  def test_finish_mobile_app_login_experiment
    @controller.expects(:finished_chronus_ab_test_only_use_cookie).with(ProgramAbTest::Experiment::MOBILE_APP_LOGIN_WORKFLOW, true, true)
    post :finish_mobile_app_login_experiment, params: { uniq_token: "uniq_token", format: :json }
    assert_response :success
  end

end