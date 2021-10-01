require_relative './../../../test_helper.rb'

class DummyOpenAuthUtilsController < ApplicationController
  include OpenAuthUtils::Extensions

  before_action :set_auth_config
  skip_all_action_callbacks only: [:callback_redirect, :open_auth_callback_params_in_session]

  def external_redirect
    callback_url = get_open_auth_callback_url
    redirect_to open_auth_authorization_redirect_url(callback_url, @auth_config, params[:from_importer], params[:chronussupport])
  end

  def callback_redirect
    organization = Organization.find(params[:organization_id])
    redirect_to get_redirect_url_from_oauth_callback(organization, permitted_callback_params)
  end

  def validate_state
    raise "State Mismatch!" unless is_open_auth_state_valid?
    head :ok
  end

  # testing for calendar sync v2
  def open_auth_callback_params_in_session
    set_open_auth_callback_params_in_session(nil, nil, nil, {
      source_controller_action: { controller: OAuthCredentialsController.controller_name, action: "callback" },
      oauth_callback_param_value: GoogleOAuthCredential,
      use_browsertab_in_mobile: true,
    })
    head :ok
  end

  private

  def set_auth_config
    @auth_config = @current_organization.linkedin_oauth
  end

  def permitted_callback_params
    params.require(:callback_params).permit(:controller, :action, :browsertab, :chronussupport, OpenAuth::CALLBACK_PARAM)
  end
end

class OpenAuthUtils::ExtensionsTest < ActionController::TestCase
  tests DummyOpenAuthUtilsController

  def setup
    super
    @user = users(:f_mentor)
    @organization = @user.program.organization
  end

  def test_open_auth_authorization_redirect
    current_user_is @user
    session.stubs(:id).returns("session-id")
    get :external_redirect
    assert_open_auth_redirect(@organization, "session-id")
    assert_equal_hash( { "controller" => SessionsController.controller_name, "action" => "new", "oauth_callback" => OpenAuthUtils::Configurations::Linkedin::CALLBACK_PARAM_VALUE }, session[:oauth_callback_params])
  end

  def test_open_auth_authorization_redirect_from_importer
    current_user_is @user
    session.stubs(:id).returns("session-id")
    get :external_redirect, params: { from_importer: true }
    assert_open_auth_redirect(@organization, "session-id")
    assert_equal_hash( {
      "controller" => LinkedinImportController.controller_name,
      "action" => "callback",
      OpenAuth::CALLBACK_PARAM => OpenAuthUtils::Configurations::Linkedin::CALLBACK_PARAM_VALUE
    }, session[:oauth_callback_params])
  end

  def test_open_auth_authorization_redirect_chronussupport
    current_user_is @user
    session.stubs(:id).returns("session-id")
    get :external_redirect, params: { chronussupport: true }
    assert_open_auth_redirect(@organization, "session-id")
    assert_equal_hash( {
      "controller" => SessionsController.controller_name,
      "action" => "new",
      "chronussupport" => true,
      OpenAuth::CALLBACK_PARAM => OpenAuthUtils::Configurations::Linkedin::CALLBACK_PARAM_VALUE,
    }, session[:oauth_callback_params])
  end

  def test_open_auth_authorization_redirect_browsertab
    current_user_is @user
    @controller.stubs(:is_mobile_app?).returns(true)
    AuthConfig.any_instance.stubs(:use_browsertab_in_mobile?).returns(true)
    session.stubs(:id).returns("session-id")
    get :external_redirect
    assert_open_auth_redirect(@organization, "session-id")
    assert_equal_hash( {
      "controller" => SessionsController.controller_name,
      "action" => "new",
      "browsertab" => true,
      OpenAuth::CALLBACK_PARAM => OpenAuthUtils::Configurations::Linkedin::CALLBACK_PARAM_VALUE,
    }, session[:oauth_callback_params])
  end

  def test_get_redirect_url_from_oauth_callback
    callback_params = {
      controller: SessionsController.controller_name,
      action: "new",
      browsertab: true,
      chronussupport: true,
      OpenAuth::CALLBACK_PARAM => OpenAuthUtils::Configurations::Linkedin::CALLBACK_PARAM_VALUE
    }

    current_subdomain_is SECURE_SUBDOMAIN
    https_get :callback_redirect, params: { state: "state", code: "12345", error: "none", ignore: "ignore", callback_params: callback_params, organization_id: @organization.id }
    assert_redirected_to "https://#{@organization.url}/session/new?chronussupport=true&code=12345&error=none&#{OpenAuth::CALLBACK_PARAM}=#{OpenAuthUtils::Configurations::Linkedin::CALLBACK_PARAM_VALUE}&state=state"
  end

  def test_is_open_auth_state_valid_success
    current_user_is @user
    assert_nothing_raised do
      get :validate_state, params: { state: "random-uuid" }, session: { OpenAuth::STATE_VARIABLE_IN_SESSION => "random-uuid" }
    end
  end

  def test_is_open_auth_state_valid_failure
    current_user_is @user
    e = assert_raise RuntimeError do
      get :validate_state, params: { state: "invalid-uuid" }, session: { OpenAuth::STATE_VARIABLE_IN_SESSION => "random-uuid" }
    end
    assert_equal "State Mismatch!", e.message
  end

  def test_set_open_auth_callback_params_in_session_for_mobile
    @controller.stubs(:is_mobile_app?).returns(true) 
    get :open_auth_callback_params_in_session
    assert session[:oauth_callback_params][:browsertab]
  end
end