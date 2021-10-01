require_relative './../../test_helper.rb'

class MatchConfigObserverTest < ActiveSupport::TestCase

  def test_after_save
    program = programs(:albers)
    prof_q = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "Choice Field1", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    prog_mentor_question = create_role_question(program: program, role_names: [RoleConstants::MENTOR_NAME], profile_question: prof_q)
    prog_student_question = create_role_question(program: program, role_names: [RoleConstants::STUDENT_NAME], profile_question: prof_q)

    MatchConfig.any_instance.stubs(:can_create_match_config_discrepancy_cache?).returns(false)
    MatchConfig.any_instance.expects(:refresh_match_config_discrepancy_cache).never
    program.match_configs.create!(
        mentor_question: prog_mentor_question,
        student_question: prog_student_question,
        show_match_label: true,
        prefix: "abc")
    
    MatchConfig.any_instance.stubs(:can_create_match_config_discrepancy_cache?).returns(true)
    MatchConfig.any_instance.expects(:refresh_match_config_discrepancy_cache).once
    program.match_configs.create!(
        mentor_question: role_questions(:single_choice_role_q),
        student_question: prog_student_question,
        show_match_label: true,
        prefix: "abc")
  end

  def test_after_update
    program = programs(:albers)
    prof_q = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "Choice Field1", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    prog_student_question = create_role_question(program: program, role_names: [RoleConstants::STUDENT_NAME], profile_question: prof_q)
    match_config = program.match_configs.create(
        mentor_question: role_questions(:single_choice_role_q),
        student_question: prog_student_question,
        show_match_label: true,
        prefix: "abc")
    MatchConfig.any_instance.stubs(:update_match_config_discrepancy_cache?).returns(true)
    match_config.expects(:refresh_match_config_discrepancy_cache).twice
    match_config.update_attributes!(show_match_label: false)
  end

end