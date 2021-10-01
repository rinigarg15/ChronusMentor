require_relative './../test_helper.rb'

class AuthConfigSettingTest < ActiveSupport::TestCase

  def setup
    super
    @auth_config_setting = programs(:org_primary).auth_config_setting
  end

  def test_validations
    assert @auth_config_setting.valid?

    @auth_config_setting.organization_id = nil
    @auth_config_setting.show_on_top = 5
    assert_false @auth_config_setting.valid?
    assert_equal ["can't be blank"], @auth_config_setting.errors[:organization_id]
    assert_equal ["is not included in the list"], @auth_config_setting.errors[:show_on_top]
  end

  def test_title_description_globalized
    @auth_config_setting.update_attributes!(
      default_section_title: "en_default_section_title",
      default_section_description: "en_default_section_description",
      custom_section_title: "en_custom_section_title",
      custom_section_description: "en_custom_section_description"
    )
    Globalize.with_locale("fr-CA") do
      @auth_config_setting.update_attributes!(
        default_section_title: "fr_default_section_title",
        default_section_description: "fr_default_section_description",
        custom_section_title: "fr_custom_section_title",
        custom_section_description: "fr_custom_section_description"
      )
    end

    assert_equal 2, @auth_config_setting.translations.count
    assert_equal "en_default_section_title", @auth_config_setting.default_section_title
    assert_equal "en_default_section_description", @auth_config_setting.default_section_description
    assert_equal "en_custom_section_title", @auth_config_setting.custom_section_title
    assert_equal "en_custom_section_description", @auth_config_setting.custom_section_description

    GlobalizationUtils.run_in_locale("fr-CA") do
      assert_equal "fr_default_section_title", @auth_config_setting.default_section_title
      assert_equal "fr_default_section_description", @auth_config_setting.default_section_description
      assert_equal "fr_custom_section_title", @auth_config_setting.custom_section_title
      assert_equal "fr_custom_section_description", @auth_config_setting.custom_section_description
    end
  end

  def test_show_default_section_on_top
    assert_equal AuthConfigSetting::Section::CUSTOM, @auth_config_setting.show_on_top
    assert_false @auth_config_setting.show_default_section_on_top?

    @auth_config_setting.show_on_top = AuthConfigSetting::Section::DEFAULT
    assert @auth_config_setting.show_default_section_on_top?
  end
end