require_relative "./../../test_helper.rb"

class AuthConfigSettingsHelperTest < ActionView::TestCase

  def test_get_auth_config_section_title
    assert_equal "Default Logins", get_auth_config_section_title(AuthConfigSetting::Section::DEFAULT)
    assert_equal "Custom Logins", get_auth_config_section_title(AuthConfigSetting::Section::CUSTOM)
  end

  def test_get_auth_config_section_header
    content = get_auth_config_section_header(AuthConfigSetting::Section::DEFAULT)
    assert_select_helper_function "h5", content, text: "Default Logins"
    assert_select_helper_function "a[href='#{auth_config_settings_path(section: AuthConfigSetting::Section::DEFAULT)}']", content, text: "Customize"

    content = get_auth_config_section_header(AuthConfigSetting::Section::CUSTOM)
    assert_select_helper_function "h5", content, text: "Custom Logins"
    assert_select_helper_function "a[href='#{auth_config_settings_path(section: AuthConfigSetting::Section::CUSTOM)}']", content, text: "Customize"
  end
end