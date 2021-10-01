require_relative './../../test_helper.rb'

class TranslationsServiceTest < ActiveSupport::TestCase

  include TranslationsService

  def test_admin_term_for_program_and_org
    admin_custom_term_at_program = programs(:albers).roles.find_by(name: RoleConstants::ADMIN_NAME).customized_term
    admin_custom_term_at_org = programs(:albers).organization.admin_custom_term
    admin_custom_term_at_program.update_attribute(:term, "Program Admin")
    admin_custom_term_at_org.update_attribute(:term, "Org Admin")
    # Program level administrator customized term is not intended to be used anywhere.
    TranslationsService.program = programs(:albers).organization
    set_terminology_helpers
    assert_equal "Org Admin", _Admin
    TranslationsService.program = programs(:albers)
    set_terminology_helpers
    assert_equal "Org Admin", _Admin
  end

  def test_program_term_for_program_and_org
    program_custom_term_at_org = programs(:albers).organization.customized_terms.find_by(term_type: CustomizedTerm::TermType::PROGRAM_TERM)
    program_custom_term_at_org.update_attribute(:term, "Unique-1 Program")
    programs(:albers).organization.reload
    TranslationsService.program = programs(:albers).organization
    set_terminology_helpers
    assert_equal "Unique-1 Program", _Program
    TranslationsService.program = programs(:albers)
    set_terminology_helpers
    assert_equal "Unique-1 Program", _Program
  end

  def test_student_term
    TranslationsService.program = programs(:albers).organization
    set_terminology_helpers
    assert_equal "Mentee", _Mentee
    TranslationsService.program = programs(:albers)
    set_terminology_helpers
    assert_equal "Student", _Mentee
  end
end