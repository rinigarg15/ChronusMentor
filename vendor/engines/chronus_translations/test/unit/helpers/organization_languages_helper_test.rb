require_relative '../../test_helper'

class OrganizationLanguagesHelperTest < ActionView::TestCase
  include OrganizationLanguagesHelper

  def test_fetch_availability_status
    organization_language = nil
    assert_equal "None", fetch_availability_status(organization_language)

    organization_language = organization_languages(:hindi)
    organization_language.update_attribute(:enabled, OrganizationLanguage::EnabledFor::NONE)
    assert_equal "None", fetch_availability_status(organization_language)

    organization_language.update_attribute(:enabled, OrganizationLanguage::EnabledFor::ADMIN)
    assert_equal "Only Administrators", fetch_availability_status(organization_language)

    organization_language.update_attribute(:enabled, OrganizationLanguage::EnabledFor::ALL)
    assert_equal "Everyone", fetch_availability_status(organization_language)
  end

  def test_get_programs_selector
    organization_language = organization_languages(:hindi)
    OrganizationLanguage.any_instance.stubs(:enabled_program_ids).returns([programs(:albers).id])

    set_response_text get_programs_selector(organization_language, "Programs Enabled For")
    assert_select "div[data-slim-scroll='false']" do
      assert_select "div.choices_wrapper[aria-label='Programs Enabled For']" do
        assert_select "input#enabled_for_program_#{programs(:albers).id}[checked='checked']"
        assert_select "input#enabled_for_program_#{programs(:nwen).id}"
        assert_select "input#enabled_for_program_#{programs(:nwen).id}[checked='checked']", count: 0
      end
    end

    Organization.any_instance.stubs(:programs).returns(Program.all)
    set_response_text get_programs_selector(organization_language, "")
    assert_select "div[data-slim-scroll='true']"
  end

  def test_get_enabled_programs_details
    assert_equal "None", get_enabled_programs_details(nil)

    organization = programs(:org_primary)
    organization_language = organization_languages(:hindi)
    OrganizationLanguage.any_instance.stubs(:enabled_program_ids).returns([])
    assert_equal "None", get_enabled_programs_details(organization_language)

    OrganizationLanguage.any_instance.stubs(:enabled_program_ids).returns(organization.program_ids)
    assert_equal "All Programs", get_enabled_programs_details(organization_language)

    OrganizationLanguage.any_instance.stubs(:enabled_program_ids).returns([programs(:albers).id])

    content = get_enabled_programs_details(organization_language)
    set_response_text content
    assert_select "span", text: "1 Program"
    assert_match(/Albers Mentor Program/, content)
  end

  private

  def _Programs
    "Programs"
  end

  def _Program
    "Program"
  end

  def _Admins
    "Administrators"
  end
end