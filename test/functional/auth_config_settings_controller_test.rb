require_relative "./../test_helper.rb"

class AuthConfigSettingsControllerTest < ActionController::TestCase

  def test_index_permission_denied
    current_member_is :f_mentor
    assert_permission_denied do
      get :index
    end
  end

  def test_index_default_section
    current_member_is :f_admin
    get :index, params: { section: AuthConfigSetting::Section::DEFAULT}
    assert_response :success
    assert_not_nil assigns(:auth_config_setting)
    assert_equal AuthConfigSetting::Section::DEFAULT, assigns(:section)
    assert_false assigns(:is_position_configurable)
    assert_select "input#auth_config_setting_default_section_title"
    assert_select "textarea#auth_config_setting_default_section_description"
    assert_no_select "input#auth_config_setting_custom_section_title"
    assert_no_select "textarea#auth_config_setting_custom_section_description"
    assert_no_select "input#auth_config_setting_show_on_top"
  end

  def test_index_custom_section
    member = members(:f_admin)
    member.organization.auth_configs.create!(auth_type: AuthConfig::Type::SAML)

    current_member_is member
    get :index, params: { section: AuthConfigSetting::Section::CUSTOM}
    assert_response :success
    assert_not_nil assigns(:auth_config_setting)
    assert_equal AuthConfigSetting::Section::CUSTOM, assigns(:section)
    assert assigns(:is_position_configurable)
    assert_no_select "input#auth_config_setting_default_section_title"
    assert_no_select "textarea#auth_config_setting_default_section_description"
    assert_select "input#auth_config_setting_custom_section_title"
    assert_select "textarea#auth_config_setting_custom_section_description"
    assert_select "input#auth_config_setting_show_on_top[checked='checked']"
  end

  def test_update_permission_denied
    member = members(:f_mentor)

    current_member_is member
    assert_permission_denied do
      patch :update, params: { id: member.organization.auth_config_setting.id }
    end
  end

  def test_update_default_section
    member = members(:f_admin)
    auth_config_setting = member.organization.auth_config_setting

    current_member_is member
    patch :update, params: {
      id: auth_config_setting.id,
      section: AuthConfigSetting::Section::DEFAULT,
      auth_config_setting: {
        default_section_title: "Other Logins",
        default_section_description: "Desc...",
        show_on_top: AuthConfigSetting::Section::DEFAULT
      }
    }
    assert_equal auth_config_setting.reload, assigns(:auth_config_setting)
    assert_equal "Other Logins", auth_config_setting.default_section_title
    assert_equal "Desc...", auth_config_setting.default_section_description
    assert auth_config_setting.show_default_section_on_top?
  end

  def test_update_custom_section
    member = members(:f_admin)
    auth_config_setting = member.organization.auth_config_setting

    current_member_is member
    patch :update, params: {
      id: auth_config_setting.id,
      section: AuthConfigSetting::Section::CUSTOM,
      auth_config_setting: {
        custom_section_title: "Other Logins",
        custom_section_description: "Desc...",
        show_on_top: AuthConfigSetting::Section::DEFAULT
      }
    }
    assert_equal auth_config_setting.reload, assigns(:auth_config_setting)
    assert_equal "Other Logins", auth_config_setting.custom_section_title
    assert_equal "Desc...", auth_config_setting.custom_section_description
    assert auth_config_setting.show_default_section_on_top?
  end
end