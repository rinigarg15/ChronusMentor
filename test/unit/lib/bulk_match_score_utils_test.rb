require_relative './../../test_helper.rb'

class BulkMatchScoreUtilsTest < ActiveSupport::TestCase
  include BulkMatchScoreUtils
  
  def test_get_match_status_for_match_config
    mentor_question = role_questions(:string_role_q)
    student_question = role_questions(:student_string_role_q)
    @current_program = mentor_question.program
    mentor = mentor_question.role.users.first
    student = student_question.role.users.first
    # no answer exists for student
    answer = ProfileAnswer.create!(answer_text: 'hellos', profile_question: student_question.profile_question, ref_obj: student.member)
    indexed_data = get_indexed_data(["mentor", "student"], @current_program)

    assert_equal_hash({score: 0.0, not_a_match: false, common_values: []}, get_match_status_for_match_config(student.id, mentor.id, indexed_data, student_question_id: student_question.id, mentor_question_id: mentor_question.id, supplementary_matching_pair: true))
    assert_equal_hash({score: 0.0, not_a_match: true, common_values: []}, get_match_status_for_match_config(student.id, mentor.id, indexed_data, student_question_id: student_question.id, mentor_question_id: mentor_question.id, threshold: 1.0, operator: "lt", supplementary_matching_pair: true))
    assert_equal_hash({score: 0.0, not_a_match: false, common_values: []}, get_match_status_for_match_config(student.id, mentor.id, indexed_data, student_question_id: student_question.id, mentor_question_id: mentor_question.id, threshold: 1.0, operator: "gt", supplementary_matching_pair: true))

    answer.answer_text = "Computer"
    answer.save!
    indexed_data = get_indexed_data(["mentor", "student"], @current_program)
    
    assert_equal_hash({score: 1.0, not_a_match: false, common_values: ["computer"]}, get_match_status_for_match_config(student.id, mentor.id, indexed_data, student_question_id: student_question.id, mentor_question_id: mentor_question.id, threshold: 1.0, operator: "gt", supplementary_matching_pair: true))
  end

  def test_get_common_data_for_matching
    mentor_question = role_questions(:string_role_q)
    student_question = role_questions(:student_string_role_q)
    match_config, student_question_1, mentor_question_1 = send(:get_common_data_for_matching, mentor_question_id: mentor_question.id, student_question_id: student_question.id, weight: 1.0, threshold: 1.0, operator: "lt", matching_details_for_matching: {})
    assert_equal student_question.profile_question, student_question_1
    assert_equal mentor_question.profile_question, mentor_question_1
    assert_equal student_question.id, match_config.student_question_id
    assert_equal mentor_question.id, match_config.mentor_question_id
    assert_equal 1.0, match_config.weight
    assert_equal 1.0, match_config.threshold
    assert_equal "lt", match_config.operator
    assert_equal Hash.new, match_config.matching_details_for_matching
  end

  def test_construct_data_field_array
    mentor_question = role_questions(:string_role_q)
    student_question = role_questions(:student_string_role_q)
    mentor = mentor_question.role.users.first
    profile_answer = profile_answers(:one)
    profile_question = profile_answer.profile_question
    indexed_data = get_indexed_data(["mentor", "student"], mentor.program)
    data_field_array = construct_data_field_array(mentor_question.profile_question, mentor, mentor_question.role.name, indexed_data)
    assert_equal [[mentor.id, profile_answer.id, profile_answer.answer_text, profile_question.question_type, profile_question.question_text, nil, nil, nil, nil, nil, nil, nil, nil, nil, mentor.id, nil]], data_field_array
  end

  def test_get_indexed_data
    program = programs(:albers)
    indexed_data = get_indexed_data([RoleConstants::STUDENT_NAME, RoleConstants::MENTOR_NAME], program)
    mentor_answer = profile_answers(:profile_answers_11)
    student_answer = profile_answers(:profile_answers_12)
    
    assert_equal_unordered ["student", "mentor"], indexed_data.keys
    assert_equal [[28, mentor_answer.id, "Manager2 Name2, manager2@example.com", mentor_answer.profile_question.question_type, "Current Manager", nil, nil, nil, nil, nil, nil, nil, nil, nil, 28, nil]], indexed_data["mentor"][mentor_answer.id]
    assert_equal [[11, student_answer.id, "Existing Manager1 Name2, userrahim@example.com", student_answer.profile_question.question_type, "Current Manager", nil, nil, nil, nil, nil, nil, nil, nil, nil, 11, nil]], indexed_data["student"][student_answer.id]
  end

  def test_get_indexed_data_custom_sql_query
    program = programs(:albers)
    mentor = program.mentor_users.first
    student = program.student_users.first
    user_ids = [mentor.id, student.id]
    user_ids_str = [mentor.id, student.id].join(",")
    assert_no_match "`users`.`id` IN (#{user_ids_str})", CustomSqlQuery::INDEX_DATA.call(CustomSqlQuery::SelectColumns::ANSWERS_FIELDS, program.id, RoleConstants::MENTOR_NAME, program.get_role(RoleConstants::MENTOR_NAME).id)
    assert_match "`users`.`id` IN (#{user_ids_str})", CustomSqlQuery::INDEX_DATA.call(CustomSqlQuery::SelectColumns::ANSWERS_FIELDS, program.id, RoleConstants::MENTOR_NAME, program.get_role(RoleConstants::MENTOR_NAME).id, user_ids: user_ids)
  end
end