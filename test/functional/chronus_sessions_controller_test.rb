require_relative './../test_helper.rb'

class ChronusSessionsControllerTest < ActionController::TestCase
  def test_new_does_not_need_app_login
    get :new
    assert_response :success
    assert_template 'new'
    assert !@controller.send(:super_console?)
  end

  def test_create_success
    post :create, params: { :passphrase => APP_CONFIG[:super_console_pass_phrase]}
    assert_redirected_to root_path
    assert @controller.send(:super_console?)
  end

  def test_create_failure
    post :create, params: { :passphrase => "abc3qas"}
    assert_equal "Login failed", flash[:error]
    assert_response :success
    assert_template 'new'
    assert !@controller.send(:super_console?)
  end

  def test_create_success_development_env
    Rails.stubs(:env).returns(ActiveSupport::StringInquirer.new("development"))
    post :create, params: { :passphrase => APP_CONFIG[:super_console_pass_phrase]}
    assert_redirected_to root_path
    assert @controller.send(:super_console?)
  end

  def test_create_failure_development_env_with_production_passphrase
    Rails.stubs(:env).returns(ActiveSupport::StringInquirer.new("development"))
    post :create, params: { :passphrase => "Varam2007!"}
    assert_equal "Login failed", flash[:error]
    assert_response :success
    assert_template 'new'
    assert !@controller.send(:super_console?)
  end

  def test_create_failure_development_env
    Rails.stubs(:env).returns(ActiveSupport::StringInquirer.new("development"))
    post :create, params: { :passphrase => "abc3qas"}
    assert_equal "Login failed", flash[:error]
    assert_response :success
    assert_template 'new'
    assert !@controller.send(:super_console?)
  end

  def test_logout
    get :destroy
    assert_redirected_to root_path
  end
end
