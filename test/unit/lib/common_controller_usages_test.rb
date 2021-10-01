require_relative './../../test_helper.rb'

class DummyCommonControllerUsagesController < ApplicationController
  skip_before_action :login_required_in_program, :require_program

  before_action :initialize_user, only: [:welcome_user]
  before_action :initialize_member, only: [:welcome_member, :assign_external_params, :handle_member]

  def welcome_user
    if params[:not_eligible_to_join_roles].present?
      program = @user.program
      not_eligible_to_join_roles = params[:not_eligible_to_join_roles].map { |role_name| program.find_role(role_name) }
    end

    options = {
      skip_login: params[:skip_login],
      newly_added_roles: params[:newly_added_roles],
      not_eligible_to_join_roles: not_eligible_to_join_roles
    }
    welcome_the_new_user(@user, options)
  end

  def welcome_member
    welcome_the_new_member(@member)
  end

  def new_external_user
    @new_user_authenticated_externally = new_user_authenticated_externally?
    @new_user_external_auth_config = new_user_external_auth_config
    head :ok
  end

  def assign_external_params
    assign_external_login_params(@member)
    head :ok
  end

  def handle_member
    if params[:hide_flash_and_prevent_redirect]
      @redirect_path = handle_member_who_can_signin_during_signup(@member, prevent_redirect: true, hide_flash: true)
      head :ok
    else
      handle_member_who_can_signin_during_signup(@member)
    end
  end

  private

  def initialize_user
    @user = User.find_by(id: params[:id])
  end

  def initialize_member
    @member = Member.find_by(id: params[:id])
  end
end

class CommonControllerUsagesTest < ActionController::TestCase
  tests DummyCommonControllerUsagesController

  def setup
    super
    @organization = programs(:org_primary)
    current_organization_is @organization
  end

  def test_welcome_user
    user = users(:f_mentor)

    Timecop.freeze(Time.now) do
      User.expects(:send_at).with(30.minutes.from_now, :send_welcome_email, user.id, []).once
      get :welcome_user, params: { id: user.id}
    end
    assert_equal user, assigns(:current_user)
    assert_equal "Welcome to #{user.program.name}. Please complete your online profile to proceed.", flash[:notice]
    assert_redirected_to edit_member_path(user.member, first_visit: user.role_names.join(COMMON_SEPARATOR), ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
  end

  def test_welcome_user_skip_login
    user = users(:f_mentor)
    user.update_attribute(:state, User::Status::PENDING)

    Timecop.freeze(Time.now) do
      User.expects(:send_at).with(30.minutes.from_now, :send_welcome_email, user.id, []).once
      get :welcome_user, params: { id: user.id, skip_login: true}
    end
    assert_nil assigns(:current_user)
    assert_equal "Welcome to #{user.program.name}. Please complete and publish your online profile to proceed.", flash[:notice]
    assert_redirected_to edit_member_path(user.member, first_visit: user.role_names.join(COMMON_SEPARATOR), ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
  end

  def test_welcome_user_newly_added_and_ineligible_roles
    user = users(:f_mentor)

    Timecop.freeze(Time.now) do
      User.expects(:send_at).with(30.minutes.from_now, :send_welcome_email, user.id, [RoleConstants::MENTOR_NAME]).once
      get :welcome_user, xhr: true, params: { id: user.id, newly_added_roles: [RoleConstants::MENTOR_NAME], not_eligible_to_join_roles: [RoleConstants::STUDENT_NAME]}
    end
    assert_equal user, assigns(:current_user)
    assert_equal "Welcome to #{user.program.name}. Please complete your online profile to proceed. However you are not allowed to join as a student.", flash[:warning]
    assert_equal "window.location.href = \"#{edit_member_path(user.member, first_visit: user.role_names.join(COMMON_SEPARATOR), ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)}\";", @response.body
  end

  def test_welcome_member
    member = members(:f_mentor)

    get :welcome_member, params: { id: member.id}
    assert_equal member, assigns(:current_member)
    assert_equal "Welcome! Your account has been successfully created", flash[:notice]
    assert_redirected_to root_organization_path
  end

  def test_new_external_user_without_external_user
    get :new_external_user
    assert_false assigns(:new_user_authenticated_externally)
    assert_nil assigns(:new_user_external_auth_config)
  end

  def test_new_external_user_with_external_user
    set_external_user_session
    get :new_external_user
    assert assigns(:new_user_authenticated_externally)
    assert_equal @auth_config, assigns(:new_user_external_auth_config)
  end

  def test_assign_external_params_without_external_user
    member = members(:f_mentor)
    linkedin_oauth = @organization.linkedin_oauth
    linkedin_oauth.disable!
    login_identifiers = member.login_identifiers

    @request.session[:linkedin_access_token] = "12345"
    @request.session[:linkedin_login_identifier] = "abcde"
    get :assign_external_params, params: { id: member.id}
    login_identifier = assigns(:member).login_identifiers.find(&:new_record?)
    assert_equal "12345", assigns(:member).linkedin_access_token
    assert_equal "abcde", login_identifier.identifier
    assert_equal linkedin_oauth.id, login_identifier.auth_config_id
    assert_equal_unordered login_identifiers + [login_identifier], assigns(:member).login_identifiers
  end

  def test_assign_external_params_should_not_override_linkedin_login_identifier
    member = members(:f_mentor)
    linkedin_oauth = @organization.linkedin_oauth
    member.login_identifiers.create!(auth_config: linkedin_oauth, identifier: "12345")

    @request.session[:linkedin_login_identifier] = "abcde"
    get :assign_external_params, params: { id: member.id}
    assert_nil assigns(:member).login_identifiers.find(&:new_record?)
    assert_equal "12345", assigns(:member).login_identifiers.find_by(auth_config_id: linkedin_oauth.id).identifier
  end

  def test_assign_external_params_with_external_user
    member = members(:f_mentor)
    login_identifiers = member.login_identifiers

    set_external_user_session
    @request.session[:linkedin_access_token] = "li12345"
    get :assign_external_params, params: { id: member.id}
    login_identifier = assigns(:member).login_identifiers.find(&:new_record?)
    assert_equal "li12345", assigns(:member).linkedin_access_token
    assert_equal "12345", login_identifier.identifier
    assert_equal @auth_config, login_identifier.auth_config
    assert_equal_unordered login_identifiers + [login_identifier], assigns(:member).login_identifiers

    member.reload
    assert_equal login_identifiers, member.login_identifiers
    assert_nil member.linkedin_access_token
  end

  def test_handle_member_when_standalone_auth
    member = members(:f_mentor)
    chronus_auth = @organization.chronus_auth

    @request.session[:auth_config_id] = { @organization.id => chronus_auth.id }
    get :handle_member, params: { id: member.id}
    assert_redirected_to login_path(auth_config_ids: [chronus_auth.id])
    assert_equal "Please login to join the program.", flash[:info]
    assert_nil @request.session[:auth_config_id]
  end

  def test_handle_member_when_standalone_remote_auth
    member = members(:f_mentor)

    AuthConfig.any_instance.stubs(:remote_login?).returns(true)
    get :handle_member, params: { id: member.id}
    assert_redirected_to login_path
    assert_nil flash[:info]
    assert_equal @organization.chronus_auth.id, @request.session[:auth_config_id][@organization.id]
  end

  def test_handle_member_when_multiple_auths
    member = members(:f_mentor)
    linkedin_oauth = @organization.linkedin_oauth
    member.login_identifiers.create!(auth_config: linkedin_oauth, identifier: "12345")

    get :handle_member, params: { id: member.id}
    assert_redirected_to login_path(auth_config_ids: [@organization.chronus_auth.id, linkedin_oauth.id])
    assert_equal "Please login to join the program.", flash[:info]
  end

  def test_handle_member_with_hide_flash_and_prevent_redirect
    member = members(:f_mentor)

    get :handle_member, params: { id: member.id, hide_flash_and_prevent_redirect: true}
    assert_response :success
    assert_nil flash[:info]
    assert_equal login_path(auth_config_ids: [@organization.chronus_auth.id]), assigns(:redirect_path)
  end

  private

  def set_external_user_session
    @auth_config = @organization.linkedin_oauth
    @request.session[:new_custom_auth_user] = {
      @organization.id => "12345",
      auth_config_id: @auth_config.id
    }
  end
end