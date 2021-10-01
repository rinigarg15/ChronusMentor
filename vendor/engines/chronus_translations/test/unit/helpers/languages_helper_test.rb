require_relative '../../test_helper'
class LanguagesHelperTest < ActiveSupport::TestCase
  include LanguagesHelper

  def test_get_available_languages
    program = programs(:albers)
    org = program.organization
    @current_organization = org
    @current_program = program
    ProgramLanguage.destroy_all
    Organization.any_instance.expects(:language_settings_enabled?).at_least(1).returns(true)
    LanguagesHelperTest.any_instance.stubs(:super_console?).returns(false)
    available_languages = get_available_languages
    languages = [{ title_for_display: "English", language_name: "en" }]
    assert_equal available_languages, languages

    organization_language = organization_languages(:hindi)
    organization_language.enabled = OrganizationLanguage::EnabledFor::ALL
    organization_language.program_ids_to_enable = [program.id]
    organization_language.save!

    available_languages = get_available_languages
    languages = [{ title_for_display: "English", language_name: "en" }, { title_for_display: "Hindi (Hindilu)", language_name: "de" }]
    assert_equal available_languages, languages

    org_lang = org.organization_languages.where(language_name: "de").first
    org_lang.update_attributes(title: "Org_Hindi", display_title: "Org_Hindilu")
    available_languages = get_available_languages
    languages = [{ title_for_display: "English", language_name: "en" }, { title_for_display: "Org_Hindi (Org_Hindilu)", language_name: "de" }]
    assert_equal available_languages, languages

    LanguagesHelperTest.any_instance.stubs(:super_console?).returns(true)
    OrganizationLanguage.update_all(enabled: OrganizationLanguage::EnabledFor::NONE)
    available_languages = get_available_languages
    languages = [{ title_for_display: "English", language_name: "en" }, { title_for_display: "Org_Hindi (Org_Hindilu)", language_name: "de" }, { title_for_display: "Telugu (Telugulu)", language_name: "es" }]
    assert_equal available_languages, languages
    available_languages = get_available_languages({from_non_org: true})
    languages = [{ title_for_display: "English", language_name: "en" }, { title_for_display: "Hindi (Hindilu)", language_name: "de" }, { title_for_display: "Telugu (Telugulu)", language_name: "es" }]
    assert_equal available_languages, languages
  end

  private

  def wob_member
    members(:f_mentor)
  end

  def program_context
    programs(:albers)
  end
end