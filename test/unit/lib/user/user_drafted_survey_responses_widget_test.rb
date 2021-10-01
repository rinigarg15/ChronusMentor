require_relative './../../../test_helper'

class UserDraftedSurveyResponsesWidgetTest < ActiveSupport::TestCase
  def test_drafted_survey_answers
    user = users(:no_mreq_student)
    assert_equal [common_answers(:q3_from_answer_draft).id], user.drafted_survey_answers.pluck(:id)

    common_answers(:q3_from_answer_draft).update_attribute(:is_draft, false)
    assert_equal [], user.drafted_survey_answers.pluck(:id)
  end

  def test_available_program_surveys
    s = surveys(:one)
    program = programs(:albers)
    assert_equal_unordered [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], s.recipient_role_names

    assert_false users(:f_admin).available_program_surveys.pluck(:id).include?(s.id)
    assert users(:f_mentor).available_program_surveys.pluck(:id).include?(s.id)
    assert users(:f_student).available_program_surveys.pluck(:id).include?(s.id)

    s.recipient_role_names = [RoleConstants::STUDENT_NAME]
    assert_false users(:f_mentor).available_program_surveys.pluck(:id).include?(s.id)
    assert users(:f_student).available_program_surveys.pluck(:id).include?(s.id)
  end

  def test_show_drafted_surveys_widget
    user = users(:no_mreq_student)
    survey = surveys(:progress_report)
    answer = common_answers(:q3_from_answer_draft)

    assert user.show_drafted_surveys_widget?
    
    answer.update_attribute(:group_id, nil)
    assert_false user.reload.show_drafted_surveys_widget?

    survey.update_attribute(:type, Survey::Type::PROGRAM)
    survey = ProgramSurvey.find(survey.id)
    survey.recipient_role_names = [RoleConstants::STUDENT_NAME]
    assert user.reload.show_drafted_surveys_widget?

    survey.recipient_role_names = [RoleConstants::MENTOR_NAME]
    assert_false user.reload.show_drafted_surveys_widget?

    user.role_names += [RoleConstants::MENTOR_NAME]
    assert user.reload.show_drafted_surveys_widget?

    survey.update_attribute(:due_date, 1.week.ago)
    assert_false user.reload.show_drafted_surveys_widget?

    survey.update_attribute(:due_date, 1.week.from_now)
    assert user.reload.show_drafted_surveys_widget?

    answer.update_attribute(:is_draft, false)
    assert_false user.reload.show_drafted_surveys_widget?
  end

  def test_drafted_responses_for_widget
    user = users(:f_student)
    s1 = programs(:albers).surveys.find_by(name: "Mentor Role User Experience Survey")
    s2 = programs(:albers).surveys.find_by(name: "Mentee Role User Experience Survey")
    assert user.available_program_surveys.include?(s1)
    assert user.available_program_surveys.include?(s2)
    q1 = s1.survey_questions.find_by(question_text: "How long have you been a member of this mentoring program?")
    q2 = s2.survey_questions.find_by(question_text: "How long have you been a member of this mentoring program?")

    survey_response1 = Survey::SurveyResponse.new(s1, {:user_id => user.id, is_draft: true})
    survey_response2 = Survey::SurveyResponse.new(s2, {:user_id => user.id, is_draft: true})
    survey_response1.save_answers({q1.id => "Less than 1 Month"})
    survey_response2.save_answers({q2.id => "Less than 1 Month"})

    srs = user.reload.drafted_responses_for_widget
    assert_equal s1.id, srs.first.survey_id
    assert_equal survey_response1.id, srs.first.response_id
    assert_equal s2.id, srs.last.survey_id
    assert_equal survey_response2.id, srs.last.response_id
  end
end