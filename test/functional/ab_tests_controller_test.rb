require_relative "./../test_helper.rb"

class AbTestsControllerTest < ActionController::TestCase
  def test_not_logged_in_organization
    login_as_super_user
    current_organization_is :org_primary

    get :index
    assert_redirected_to new_session_path

    post :update_for_program
    assert_redirected_to new_session_path
  end

  def test_not_super_console
    current_user_is :f_admin

    get :index
    assert_redirected_to super_login_path

    post :update_for_program
    assert_redirected_to super_login_path
  end

  def test_not_logged_in_current_level
    login_as_super_user
    current_member_is :ram
    current_program_is :nwen

    assert_permission_denied do
      get :index
    end

    assert_permission_denied do
      post :update_for_program
    end
  end

  def test_index_success_for_org
    login_as_super_user
    current_member_is :f_admin
    
    get :index
    assert_response :success
  end

  def test_index_success
    login_as_super_user
    current_user_is :f_admin

    get :index
    assert_response :success
  end

  def test_update_for_program_success_for_org
    login_as_super_user
    current_member_is :f_admin
    org = programs(:org_primary)

    ProgramAbTest.stubs(:experiments).returns(['t1', 't2'])
    org.ab_tests.create!(test: 't1', enabled: true)
    
    assert_difference "ProgramAbTest.count", 1 do
      post :update_for_program
    end

    assert_false org.reload.ab_tests.find_by(test: 't1').enabled?
    assert_false org.reload.ab_tests.find_by(test: 't2').enabled?

    assert_equal "A/B tests have been successfully enabled/disabled", flash[:notice]
    assert_redirected_to ab_tests_path

    assert_no_difference "ProgramAbTest.count" do
      post :update_for_program, params: { :experiments => ['t2']}
    end

    assert_false org.reload.ab_tests.find_by(test: 't1').enabled?
    assert org.reload.ab_tests.find_by(test: 't2').enabled?

    assert_equal "A/B tests have been successfully enabled/disabled", flash[:notice]
    assert_redirected_to ab_tests_path
  end

  def test_update_for_program_success
    login_as_super_user
    current_user_is :f_admin
    prog = programs(:albers)

    ProgramAbTest.stubs(:experiments).returns(['t1', 't2'])
    prog.ab_tests.create!(test: 't1', enabled: true)
    
    assert_difference "ProgramAbTest.count", 1 do
      post :update_for_program
    end

    assert_false prog.reload.ab_tests.find_by(test: 't1').enabled?
    assert_false prog.reload.ab_tests.find_by(test: 't2').enabled?

    assert_equal "A/B tests have been successfully enabled/disabled", flash[:notice]
    assert_redirected_to ab_tests_path

    assert_no_difference "ProgramAbTest.count" do
      post :update_for_program, params: { :experiments => ['t2']}
    end

    assert_false prog.reload.ab_tests.find_by(test: 't1').enabled?
    assert prog.reload.ab_tests.find_by(test: 't2').enabled?

    assert_equal "A/B tests have been successfully enabled/disabled", flash[:notice]
    assert_redirected_to ab_tests_path
  end
end