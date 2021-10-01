require_relative '../test_helper'

class OrganizationLanguageTest < ActiveSupport::TestCase
  def test_validates_member
    organization_language = OrganizationLanguage.new(enabled: -1)
    assert_false organization_language.valid?
    assert_equal(["can't be blank"], organization_language.errors[:organization])
    assert_equal(["can't be blank"], organization_language.errors[:language])
    assert_equal(["is not included in the list"], organization_language.errors[:enabled])
    organization_language = OrganizationLanguage.create!(:organization => programs(:org_primary), :language => languages(:hindi))
    assert organization_language.valid?
  end

  def test_belongs_to
    organization = programs(:org_primary)
    language = languages(:hindi)
    organization_language = OrganizationLanguage.create!(:organization => programs(:org_primary), :language => language)
    assert_equal organization_language.organization, organization
    assert_equal organization_language.language, language
  end

  def test_has_many
    organization_language = organization_languages(:hindi)
    assert_equal 5, organization_language.program_languages.size
  end

  def test_scopes
    organization = programs(:org_primary)
    hindi = organization_languages(:hindi)
    telugu = organization_languages(:telugu)
    assert_equal_unordered [hindi, telugu].collect(&:id), organization.organization_languages.pluck(:id)
    assert_equal_unordered [hindi, telugu].collect(&:id), organization.organization_languages.enabled.pluck(:id)

    hindi.update_attributes!(enabled: OrganizationLanguage::EnabledFor::ADMIN)
    assert_equal_unordered [hindi, telugu].collect(&:id), organization.organization_languages.all.pluck(:id)
    assert_equal_unordered [telugu].collect(&:id), organization.organization_languages.enabled.pluck(:id)

    hindi.update_attributes!(enabled: OrganizationLanguage::EnabledFor::NONE)
    assert_equal_unordered [telugu].collect(&:id), organization.organization_languages.all.pluck(:id)
    assert_equal_unordered [telugu].collect(&:id), organization.organization_languages.enabled.pluck(:id)
  end

  def test_enabled_for_admin
    organization_language = organization_languages(:hindi)
    assert_false organization_language.enabled_for_admin?

    organization_language.update_attributes(enabled: OrganizationLanguage::EnabledFor::ADMIN)
    assert organization_language.enabled_for_admin?
  end

  def test_enabled_for_all
    organization_language = organization_languages(:hindi)
    assert organization_language.enabled_for_all?

    organization_language.update_attributes(enabled: OrganizationLanguage::EnabledFor::ADMIN)
    assert_false organization_language.enabled_for_all?
  end

  def test_disabled
    organization_language = organization_languages(:hindi)
    assert_false organization_language.disabled?

    organization_language.update_attributes(enabled: OrganizationLanguage::EnabledFor::NONE)
    assert organization_language.disabled?
  end

  def test_enabled_program_ids
    organization = programs(:org_primary)
    organization_language = organization_languages(:hindi)
    assert_equal_unordered organization.program_ids, organization_language.enabled_program_ids

    new_enabled_program_ids = organization.program_ids[0..-2]
    organization_language.program_ids_to_enable = new_enabled_program_ids
    organization_language.handle_enabled_program_languages
    assert_equal_unordered new_enabled_program_ids, organization_language.enabled_program_ids
  end

  def test_handle_enabled_program_languages
    organization = programs(:org_primary)
    organization_language = organization_languages(:hindi)
    enabled_program_ids = organization_language.enabled_program_ids

    assert_difference "ProgramLanguage.count", -1 do
      organization_language.program_ids_to_enable = enabled_program_ids[0..-2]
      organization_language.handle_enabled_program_languages
    end

    assert_difference "ProgramLanguage.count" do
      organization_language.program_ids_to_enable = enabled_program_ids
      organization_language.handle_enabled_program_languages
    end

    organization_language.stubs(:disabled?).returns(true)
    assert_difference "ProgramLanguage.count", -organization_language.program_languages.size do
      organization_language.program_ids_to_enable = enabled_program_ids
      organization_language.handle_enabled_program_languages
    end

    organization_language.stubs(:disabled?).returns(false)
    assert_no_difference "ProgramLanguage.count" do
      organization_language.handle_enabled_program_languages
    end
  end

  def test_to_display
    hindi = organization_languages(:hindi)
    assert_equal "Hindi (Hindilu)", hindi.to_display
    assert_equal "English", OrganizationLanguage.for_english.to_display
  end

  def test_for_english
    english_language = Language.for_english
    english_org_language = OrganizationLanguage.for_english
    assert english_org_language.enabled
    assert_equal english_language.title, english_org_language.title
    assert_nil english_language.display_title
    assert_nil english_org_language.display_title
    assert_equal english_language.language_name, english_org_language.language_name
  end
end
