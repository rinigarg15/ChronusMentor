require_relative '../test_helper'

class MatchConfigDiscrepancyCacheTest < ActiveSupport::TestCase
  def test_validations
    @program = programs(:albers)
    prof_q = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "Choice Field1", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    prog_mentor_question = create_role_question(program: @program, role_names: [RoleConstants::MENTOR_NAME], profile_question: prof_q)
    prog_student_question = create_role_question(program: @program, role_names: [RoleConstants::STUDENT_NAME], profile_question: prof_q)
    match_config = MatchConfig.create(
        program: programs(:albers),
        mentor_question: prog_mentor_question,
        student_question: prog_student_question,
        show_match_label: true,
        prefix: "abc")

    match_config_discrepancy_cache = MatchConfigDiscrepancyCache.new
    assert_false match_config_discrepancy_cache.valid?
    assert_equal ["can't be blank"], match_config_discrepancy_cache.errors.messages[:match_config]

    match_config_discrepancy_cache.match_config_id = match_config.id
    assert match_config_discrepancy_cache.valid?
  end

  def test_refresh_top_discrepancies
    @program = programs(:albers)
    prof_q = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "Choice Field1", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    prog_mentor_question = create_role_question(program: @program, role_names: [RoleConstants::MENTOR_NAME], profile_question: prof_q)
    prog_student_question = create_role_question(program: @program, role_names: [RoleConstants::STUDENT_NAME], profile_question: prof_q)
    match_config = MatchConfig.create(
        program: programs(:albers),
        mentor_question: prog_mentor_question,
        student_question: prog_student_question,
        show_match_label: true,
        prefix: "abc")
    MatchConfigDiscrepancyCache.create!(match_config: match_config, top_discrepancy: [{"discrepancy"=>4, "student_need_count"=>8, "mentor_offer_count"=>4, "student_answer_choice"=>"20+ years"}])

    MatchReport::Sections::SectionClasses[MatchReport::Sections::MentorDistribution].constantize.any_instance.stubs(:calculate_data_discrepancy).returns([1, 2, 3])
    MatchConfigDiscrepancyCache.refresh_top_discrepancies
    MatchConfigDiscrepancyCache.find_each do |match_config_discrepancy_cache|
      assert_equal [1, 2, 3], match_config_discrepancy_cache.reload.top_discrepancy
    end
  end

  def test_check_match_config_question_choice_based_or_location
    @program = programs(:albers)
    prof_q = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "Choice Field1", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    prog_student_question = create_role_question(program: @program, role_names: [RoleConstants::STUDENT_NAME], profile_question: prof_q)
    match_config = MatchConfig.create(
        program: programs(:albers),
        mentor_question: role_questions(:string_role_q),
        student_question: prog_student_question,
        show_match_label: true,
        prefix: "abc")
    match_config_discrepancy_cache = MatchConfigDiscrepancyCache.new(match_config: match_config)

    assert_raise ActiveRecord::RecordInvalid, "activerecord.custom_errors.match_config_discrepancy_cache.cant_be_cached".translate do
      match_config_discrepancy_cache.save!
    end
  end
end