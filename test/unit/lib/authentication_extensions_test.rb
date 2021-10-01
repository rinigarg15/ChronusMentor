require_relative './../../test_helper.rb'

class DummyAuthenticationExtensionsController < ApplicationController
  include AuthenticationExtensions

  skip_before_action :login_required_in_program, :require_program

  def fetch_auth_config
    params.merge!(controller: "sessions", action: ["new", "create"].sample) unless params[:skip_login_context]

    @openssl_user_attributes = openssl_user_attributes
    @saml_response = saml_response
    @bbnc_attributes = bbnc_attributes
    @bbnc_attributes_present = bbnc_attributes_present?
    @cookie_attributes = cookie_attributes
    @cookies_for_sso_present = cookies_for_sso_present?
    @soap_token_present = soap_token_present?
    @oauth_flag = oauth_flag
    @any_sso_attributes_present = any_sso_attributes_present?

    @auth_config = get_and_set_current_auth_config
    head :ok
  end

  def import_data
    @session_import_data = session_import_data
    @session_import_data_email = session_import_data_email
    @session_import_data_name = session_import_data_name
    head :ok
  end

  def login_sections
    initialize_login_sections
    head :ok
  end
end

class AuthenticationExtensionsTest < ActionController::TestCase
  tests DummyAuthenticationExtensionsController

  def setup
    super
    @organization = programs(:org_primary)
    current_organization_is @organization
  end

  def test_fetch_auth_config_openssl
    openssl_auth = @organization.auth_configs.create!(auth_type: AuthConfig::Type::OPENSSL)

    get :fetch_auth_config, params: { login_data: "DATA" }
    assert_response :success
    assert_equal "DATA", assigns(:openssl_user_attributes)
    assert assigns(:any_sso_attributes_present)
    assert_equal openssl_auth, assigns(:auth_config)
    assert_equal openssl_auth.id, session[:auth_config_id][@organization.id]
  end

  def test_fetch_auth_config_saml
    saml_auth = @organization.auth_configs.create!(auth_type: AuthConfig::Type::SAML)

    get :fetch_auth_config, params: { SAMLResponse: "RESPONSE" }
    assert_response :success
    assert_equal "RESPONSE", assigns(:saml_response)
    assert assigns(:any_sso_attributes_present)
    assert_equal saml_auth, assigns(:auth_config)
    assert_equal saml_auth.id, session[:auth_config_id][@organization.id]
  end

  def test_fetch_auth_config_bbnc
    bbnc_auth = @organization.auth_configs.create!(auth_type: AuthConfig::Type::BBNC)

    get :fetch_auth_config, params: { userid: "USERID", ts: "OCT09", sig: "SIGNATURE" }
    assert_response :success
    assert_equal_hash( { userid: "USERID", ts: "OCT09", sig: "SIGNATURE" }, assigns(:bbnc_attributes))
    assert assigns(:bbnc_attributes_present)
    assert assigns(:any_sso_attributes_present)
    assert_equal bbnc_auth, assigns(:auth_config)
    assert_equal bbnc_auth.id, session[:auth_config_id][@organization.id]
  end

  def test_fetch_auth_config_cookie
    cookie_auth = @organization.auth_configs.create!(auth_type: AuthConfig::Type::Cookie)

    cookies[:enc_constitid] = "COOKIE"
    get :fetch_auth_config
    assert_response :success
    assert_equal_hash( { encrypted_uid: "COOKIE" }, assigns(:cookie_attributes))
    assert assigns(:cookies_for_sso_present)
    assert assigns(:any_sso_attributes_present)
    assert_equal cookie_auth, assigns(:auth_config)
    assert_equal cookie_auth.id, session[:auth_config_id][@organization.id]
  end

  def test_fetch_auth_config_soap
    soap_auth = @organization.auth_configs.create!(auth_type: AuthConfig::Type::SOAP)

    get :fetch_auth_config, params: { nftoken: "TOKEN" }
    assert_response :success
    assert assigns(:soap_token_present)
    assert assigns(:any_sso_attributes_present)
    assert_equal soap_auth, assigns(:auth_config)
    assert_equal soap_auth.id, session[:auth_config_id][@organization.id]
  end

  def test_fetch_auth_config_linkedin_oauth
    linkedin_oauth = @organization.linkedin_oauth

    get :fetch_auth_config, params: { OpenAuth::CALLBACK_PARAM => OpenAuthUtils::Configurations::Linkedin::CALLBACK_PARAM_VALUE }
    assert_response :success
    assert_equal OpenAuthUtils::Configurations::Linkedin::CALLBACK_PARAM_VALUE, assigns(:oauth_flag)
    assert assigns(:any_sso_attributes_present)
    assert_equal linkedin_oauth, assigns(:auth_config)
    assert_equal linkedin_oauth.id, session[:auth_config_id][@organization.id]
  end

  def test_fetch_auth_config_google_oauth
    google_oauth = @organization.google_oauth

    get :fetch_auth_config, params: { OpenAuth::CALLBACK_PARAM => OpenAuthUtils::Configurations::Google::CALLBACK_PARAM_VALUE }
    assert_response :success
    assert_equal OpenAuthUtils::Configurations::Google::CALLBACK_PARAM_VALUE, assigns(:oauth_flag)
    assert assigns(:any_sso_attributes_present)
    assert_equal google_oauth, assigns(:auth_config)
    assert_equal google_oauth.id, session[:auth_config_id][@organization.id]
  end

  def test_fetch_auth_config_oauth
    open_auth = @organization.auth_configs.create!(auth_type: AuthConfig::Type::OPEN)

    get :fetch_auth_config, params: { OpenAuth::CALLBACK_PARAM => true }
    assert_response :success
    assert_equal "true", assigns(:oauth_flag)
    assert assigns(:any_sso_attributes_present)
    assert_equal open_auth, assigns(:auth_config)
    assert_equal open_auth.id, session[:auth_config_id][@organization.id]
  end

  def test_fetch_auth_config_when_no_sso_attrs
    get :fetch_auth_config
    assert_response :success
    assert_false assigns(:any_sso_attributes_present)
    assert_nil assigns(:auth_config)
    assert_nil session[:auth_config_id]
  end

  def test_fetch_auth_config_when_standalone_auth
    auth_configs = @organization.auth_configs.to_a
    auth_configs[1..-1].map(&:disable!)

    get :fetch_auth_config
    assert_response :success
    assert_false assigns(:any_sso_attributes_present)
    assert_equal auth_configs[0], assigns(:auth_config)
    assert_equal auth_configs[0].id, session[:auth_config_id][@organization.id]
  end

  def test_fetch_auth_config_when_id_present
    chronus_auth = @organization.chronus_auth

    get :fetch_auth_config, params: { auth_config_id: chronus_auth.id, skip_login_context: true }
    assert_response :success
    assert_false assigns(:any_sso_attributes_present)
    assert_equal chronus_auth, assigns(:auth_config)
    assert_nil session[:auth_config_id]
  end

  def test_fetch_auth_config_when_id_present_in_session
    chronus_auth = @organization.chronus_auth

    session[:auth_config_id] = { @organization.id => chronus_auth.id }
    get :fetch_auth_config
    assert_response :success
    assert_false assigns(:any_sso_attributes_present)
    assert_equal chronus_auth, assigns(:auth_config)
    assert_equal chronus_auth.id, session[:auth_config_id][@organization.id]
  end

  def test_fetch_auth_config_when_ids_present_with_only_id
    chronus_auth = @organization.chronus_auth

    get :fetch_auth_config, params: { auth_config_ids: [chronus_auth.id] }
    assert_response :success
    assert_false assigns(:any_sso_attributes_present)
    assert_equal chronus_auth, assigns(:auth_config)
    assert_equal chronus_auth.id, session[:auth_config_id][@organization.id]
  end

  def test_fetch_auth_config_when_ids_present
    get :fetch_auth_config, params: { auth_config_ids: @organization.auth_config_ids }
    assert_response :success
    assert_false assigns(:any_sso_attributes_present)
    assert_nil assigns(:auth_config)
    assert_nil session[:auth_config_id]
  end

  def test_fetch_auth_config_when_new_external_user
    linkedin_oauth = @organization.linkedin_oauth

    session[:new_custom_auth_user] = {
      @organization.id => "123",
      auth_config_id: linkedin_oauth.id
    }
    get :fetch_auth_config, params: { skip_login_context: true }
    assert_response :success
    assert_false assigns(:any_sso_attributes_present)
    assert_equal linkedin_oauth, assigns(:auth_config)
    assert_nil session[:auth_config_id]
  end

  def test_fetch_auth_config_when_no_login_context
    session[:auth_config_id] = { @organization.id => @organization.chronus_auth.id }
    get :fetch_auth_config, params: { OpenAuth::CALLBACK_PARAM => OpenAuthUtils::Configurations::Google::CALLBACK_PARAM_VALUE, skip_login_context: true }
    assert_response :success
    assert_nil assigns(:auth_config)
  end

  def test_import_data
    session[:new_user_import_data] = {
      @organization.id => { "Member" => { "first_name" => "Sundar", "last_name" => "Raja", "email" => "sun@chronus.com" } }
    }

    get :import_data
    assert_equal_hash( { "Member" => { "first_name" => "Sundar", "last_name" => "Raja", "email" => "sun@chronus.com" } }, assigns(:session_import_data))
    assert_equal "sun@chronus.com", assigns(:session_import_data_email)
    assert_equal "Sundar Raja", assigns(:session_import_data_name)
  end

  def test_import_data_when_no_external_data
    get :import_data
    assert_nil assigns(:session_import_data)
    assert_nil assigns(:session_import_data_email)
    assert_nil assigns(:session_import_data_name)
  end

  def test_login_sections_when_no_custom_section
    @organization.auth_config_setting.update_attributes!(default_section_title: "Default Logins", default_section_description: "Provided default by Chronus!")

    get :login_sections
    assert_response :success
    assert_equal 1, assigns(:login_sections).size
    assert_equal "Default Logins", assigns(:login_sections)[0][:title]
    assert_equal "Provided default by Chronus!", assigns(:login_sections)[0][:description]
    assert_equal AuthConfig.attr_value_map_for_default_auths.size, assigns(:login_sections)[0][:auth_configs].size
    assert assigns(:login_sections)[0][:auth_configs].all?(&:default?)
  end

  def test_login_sections_when_no_default_section
    custom_auth = @organization.auth_configs.create!(auth_type: AuthConfig::Type::SAML)
    @organization.auth_configs.select(&:default?).map(&:disable!)
    @organization.auth_config_setting.update_attributes!(custom_section_title: "Other", custom_section_description: "Custom Logins")

    get :login_sections
    assert_response :success
    assert_equal 1, assigns(:login_sections).size
    assert_equal "Other", assigns(:login_sections)[0][:title]
    assert_equal "Custom Logins", assigns(:login_sections)[0][:description]
    assert_equal [custom_auth], assigns(:login_sections)[0][:auth_configs]
  end

  def test_login_sections
    custom_auth = @organization.auth_configs.create!(auth_type: AuthConfig::Type::SAML)
    @organization.auth_config_setting.update_attributes!(
      default_section_title: "Default Logins",
      default_section_description: "Provided default by Chronus!",
      custom_section_title: "Other",
      custom_section_description: "Custom Logins",
      show_on_top: AuthConfigSetting::Section::DEFAULT
    )

    get :login_sections
    assert_response :success
    assert_equal 2, assigns(:login_sections).size
    assert_equal "Default Logins", assigns(:login_sections)[0][:title]
    assert_equal "Provided default by Chronus!", assigns(:login_sections)[0][:description]
    assert_equal AuthConfig.attr_value_map_for_default_auths.size, assigns(:login_sections)[0][:auth_configs].size
    assert assigns(:login_sections)[0][:auth_configs].all?(&:default?)
    assert_equal "Other", assigns(:login_sections)[1][:title]
    assert_equal "Custom Logins", assigns(:login_sections)[1][:description]
    assert_equal [custom_auth], assigns(:login_sections)[1][:auth_configs]
  end
end