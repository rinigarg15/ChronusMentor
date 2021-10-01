require_relative './../../test_helper.rb'

class FirstVisitSectionCookiesTest < ActiveSupport::TestCase
  include FirstVisitSectionCookies

  def test_set_all_section_titles
    self.instance_variable_set("@current_organization", programs(:org_primary))
    self.instance_variable_set("@profile_user", users(:f_student))
    self.instance_variable_set("@current_program", programs(:albers))
    self.stubs(:can_edit_mentoring_settings_section?).with(users(:f_student)).returns(false)
    self.instance_variable_set("@program_questions_for_user", [profile_questions(:string_q), profile_questions(:single_choice_q), profile_questions(:multi_choice_q),profile_questions(:student_string_q), profile_questions(:education_q)])

    Program.any_instance.stubs(:calendar_sync_v2_for_member_applicable?).returns(false)
    set_all_section_titles
    assert_equal [programs(:org_primary).sections.find_by(title: "Work and Education").id, sections(:section_albers).id, sections(:section_albers_students).id], self.instance_variable_get("@all_profile_section_ids")
    assert_equal_hash({programs(:org_primary).sections.find_by(title: "Work and Education").id => "Work and Education", sections(:section_albers).id => "More Information", sections(:section_albers_students).id => "More Information Students"}, self.instance_variable_get("@all_profile_section_titles_hash"))

    Program.any_instance.stubs(:calendar_sync_v2_for_member_applicable?).returns(true)
    set_all_section_titles
    assert_equal [programs(:org_primary).sections.find_by(title: "Work and Education").id, sections(:section_albers).id, sections(:section_albers_students).id, MembersController::EditSection::CALENDAR_SYNC_V2_SETTINGS], self.instance_variable_get("@all_profile_section_ids")

    self.stubs(:can_edit_mentoring_settings_section?).with(users(:f_student)).returns(true)
    set_all_section_titles
    assert_equal [programs(:org_primary).sections.find_by(title: "Work and Education").id, sections(:section_albers).id, sections(:section_albers_students).id, MembersController::EditSection::CALENDAR_SYNC_V2_SETTINGS, MembersController::EditSection::MENTORING_SETTINGS], self.instance_variable_get("@all_profile_section_ids")
  end

  def test_reject_sections_filled_with_mandatory_questions
    self.instance_variable_set("@current_organization", programs(:org_primary))
    self.instance_variable_set("@sections_filled", [programs(:org_primary).sections.find_by(title: "Work and Education").id.to_s, sections(:section_albers).id.to_s, sections(:section_albers_students).id.to_s])
    self.instance_variable_set("@profile_user", users(:f_student))
    self.instance_variable_set("@profile_member", members(:f_student))
    self.instance_variable_set("@current_program", programs(:albers))
    self.instance_variable_set("@program_questions_for_user", [profile_questions(:string_q), profile_questions(:single_choice_q), profile_questions(:multi_choice_q),profile_questions(:student_string_q), profile_questions(:education_q)])
    self.stubs(:current_user).returns(users(:f_student))

    reject_sections_filled_with_mandatory_questions!
    assert_equal [programs(:org_primary).sections.find_by(title: "Work and Education").id.to_s, sections(:section_albers).id.to_s, sections(:section_albers_students).id.to_s], self.instance_variable_get("@sections_filled")

    role_questions(:student_string_role_q).update_attributes!(required: true)
    members(:f_student).stubs(:answered_profile_questions).returns([profile_questions(:student_string_q)])
    reject_sections_filled_with_mandatory_questions!
    assert_equal [programs(:org_primary).sections.find_by(title: "Work and Education").id.to_s, sections(:section_albers).id.to_s, sections(:section_albers_students).id.to_s], self.instance_variable_get("@sections_filled")

    members(:f_student).stubs(:answered_profile_questions).returns([])
    reject_sections_filled_with_mandatory_questions!
    assert_equal [programs(:org_primary).sections.find_by(title: "Work and Education").id.to_s, sections(:section_albers).id.to_s], self.instance_variable_get("@sections_filled")
  end
end