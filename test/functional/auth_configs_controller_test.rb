require_relative "./../test_helper.rb"

class AuthConfigsControllerTest < ActionController::TestCase

  def setup
    super
    @admin = members(:f_admin)
    @non_admin = members(:f_mentor)
    @organization = @admin.organization
    @chronus_auth = @organization.chronus_auth
  end

  def test_index_permission_denied
    current_member_is @non_admin
    assert_permission_denied do
      get :index
    end
  end

  def test_index
    custom_auth = create_custom_auth
    @chronus_auth.disable!

    current_member_is @admin
    get :index
    assert_response :success
    assert_equal AuthConfig.attr_value_map_for_default_auths.size, assigns(:auth_configs)[:default].size
    assert_equal [custom_auth], assigns(:auth_configs)[:custom]
    assert assigns(:auth_configs)[:default].include?(@chronus_auth)
  end

  def test_edit_permission_denied_when_non_admin
    custom_auth = create_custom_auth

    current_member_is @non_admin
    assert_permission_denied do
      get :edit, params: { id: custom_auth.id}
    end
  end

  def test_edit_permission_denied_when_default_auth
    current_member_is @admin
    assert_permission_denied do
      get :edit, params: { id: @chronus_auth.id}
    end
  end

  def test_edit
    custom_auth = create_custom_auth

    current_member_is @admin
    get :edit, params: { id: custom_auth.id}
    assert_response :success
    assert_equal custom_auth, assigns(:auth_config)
  end

  def test_update_permission_denied_when_non_admin
    custom_auth = create_custom_auth

    current_member_is @non_admin
    assert_permission_denied do
      patch :update, params: { id: custom_auth.id, auth_config: { title: "University ID" }}
    end
  end

  def test_update_permission_denied_when_default_auth
    current_member_is @admin
    assert_permission_denied do
      patch :update, params: { id: @chronus_auth.id, auth_config: { title: "University ID" }}
    end
  end

  def test_update
    custom_auth = create_custom_auth

    current_member_is @admin
    patch :update, params: { id: custom_auth.id, auth_config: { title: "University ID", logo: fixture_file_upload(File.join("files", "test_pic.png"), "image/png") }}
    assert_redirected_to auth_configs_path
    assert_equal "'University ID' login has been customized successfully.", flash[:notice]

    custom_auth.reload
    assert_equal "University ID", custom_auth.title
    assert_equal "test_pic.png", custom_auth.logo_file_name
  end

  def test_update_remove_logo
    custom_auth = create_custom_auth
    custom_auth.logo = fixture_file_upload(File.join("files", "test_pic.png"), "image/png")
    custom_auth.save!

    current_member_is @admin
    patch :update, params: { id: custom_auth.id, auth_config: { title: "University ID" }, persist_logo: "false"}
    assert_redirected_to auth_configs_path
    assert_equal "'University ID' login has been customized successfully.", flash[:notice]

    custom_auth.reload
    assert_equal "University ID", custom_auth.title
    assert_nil custom_auth.logo_file_name
  end

  def test_update_virus_error
    custom_auth = create_custom_auth

    AuthConfig.any_instance.expects(:update_attributes!).raises(VirusError)
    current_member_is @admin
    patch :update, params: { id: custom_auth.id, auth_config: { title: "University ID" }}
    assert_redirected_to auth_configs_path
    assert_equal "Our security system has detected the presence of a virus in the attachment.", flash[:error]
  end

  def test_destroy_permission_denied
    custom_auth = create_custom_auth

    current_member_is @non_admin
    assert_permission_denied do
      delete :destroy, params: { id: custom_auth.id}
    end
  end

  def test_destroy_permission_denied_when_default_auth
    current_member_is @admin
    assert_permission_denied do
      delete :destroy, params: { id: @chronus_auth.id}
    end
  end

  def test_destroy_permission_denied_when_standalone_custom_auth
    custom_auth = create_custom_auth
    @organization.auth_configs.select(&:default?).map(&:disable!)

    current_member_is @admin
    assert_permission_denied do
      delete :destroy, params: { id: custom_auth.id}
    end
  end

  def test_destroy
    custom_auth = create_custom_auth

    current_member_is @admin
    assert_difference "AuthConfig.count", -1 do
      delete :destroy, params: { id: custom_auth.id}
    end
    assert_redirected_to auth_configs_path
    assert_equal "'Custom Logon' login has been removed successfully.", flash[:notice]
  end

  def test_toggle_permission_denied_when_non_admin
    current_member_is @non_admin
    assert_permission_denied do
      patch :toggle, params: { id: @chronus_auth.id}
    end
  end

  def test_toggle_permission_denied_when_custom_auth
    custom_auth = create_custom_auth

    current_member_is @admin
    assert_permission_denied do
      patch :toggle, params: { id: custom_auth.id}
    end
  end

  def test_toggle_disable_permission_denied_when_standalone_default_auth
    auth_configs = @organization.auth_configs
    auth_configs[1..-1].map(&:disable!)

    current_member_is @admin
    assert_permission_denied do
      patch :toggle, params: { id: auth_configs[0].id}
    end
  end

  def test_toggle_disable
    current_member_is @admin
    patch :toggle, params: { id: @chronus_auth.id}
    assert_redirected_to auth_configs_path
    assert_equal "'Email' login has been disabled successfully.", flash[:notice]
    assert_false @chronus_auth.reload.enabled?
  end

  def test_toggle_enable
    @chronus_auth.disable!

    current_member_is @admin
    patch :toggle, params: { id: @chronus_auth.id, enable: true}
    assert_redirected_to auth_configs_path
    assert_equal "'Email' login has been enabled successfully.", flash[:notice]
    assert @chronus_auth.reload.enabled?
  end

  def test_edit_password_policy_permission_denied_when_non_super_user
    current_member_is @admin
    assert_permission_denied do
      get :edit_password_policy, params: { id: @chronus_auth.id}
    end
  end

  def test_edit_password_policy_permission_denied_when_non_indigenous_auth
    login_as_super_user
    current_member_is @admin
    assert_permission_denied do
      get :edit_password_policy, params: { id: non_indigenous_auth.id}
    end
  end

  def test_edit_password_policy
    @chronus_auth.disable!

    login_as_super_user
    current_member_is @admin
    get :edit_password_policy, params: { id: @chronus_auth.id}
    assert_response :success
    assert_equal @chronus_auth, assigns(:auth_config)
  end

  def test_update_password_policy_permission_denied_when_non_super_user
    current_member_is @admin
    assert_permission_denied do
      patch :update_password_policy, params: { id: @chronus_auth.id, auth_config: { regex_string: "(?:.{8,})$", password_message: "8 chars min" }}
    end
  end

  def test_update_password_policy_permission_denied_when_non_indigenous_auth
    login_as_super_user
    current_member_is @admin
    assert_permission_denied do
      patch :update_password_policy, params: { id: non_indigenous_auth.id, auth_config: { regex_string: "(?:.{8,})$", password_message: "8 chars min" }}
    end
  end

  def test_update_password_policy
    login_as_super_user
    current_member_is @admin
    patch :update_password_policy, params: { id: @chronus_auth.id, auth_config: { regex_string: "(?:.{8,})$", password_message: "8 chars min" }}
    assert_redirected_to auth_configs_path
    assert_equal "Password Policy has been set for the 'Email' login successfully.", flash[:notice]

    @chronus_auth.reload
    assert_equal "(?:.{8,})$", @chronus_auth.regex_string
    assert_equal "8 chars min", @chronus_auth.password_message
  end

  private

  def create_custom_auth
    @organization.auth_configs.create!(auth_type: AuthConfig::Type::SAML, title: "Custom Logon")
  end

  def non_indigenous_auth
    @organization.google_oauth
  end
end