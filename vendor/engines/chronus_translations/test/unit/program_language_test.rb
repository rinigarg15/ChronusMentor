require_relative '../test_helper'

class ProgramLanguageTest < ActiveSupport::TestCase
  def test_belongs_to
    organization = programs(:org_primary)
    organization_language = organization_languages(:hindi)
    program_language = ProgramLanguage.create!(program: programs(:albers), organization_language: organization_language)
    assert_equal program_language.organization_language, organization_language
    assert_equal program_language.organization_language, organization_language
  end

  def test_validations
    program_language = ProgramLanguage.new
    assert_false program_language.valid?
    assert_equal ["can't be blank"], program_language.errors[:program]
    assert_equal ["can't be blank"], program_language.errors[:organization_language_id]

    program_language = ProgramLanguage.new(program: programs(:albers), organization_language: organization_languages(:hindi))
    assert program_language.valid?
  end
end
