require_relative './../../test_helper.rb'

class EducationObserverTest < ActiveSupport::TestCase
  def test_after_destroy_on_question_type_change
    question = profile_questions(:multi_education_q)
    answer = profile_answers(:profile_answers_1)
    assert_equal 2, question.profile_answers.reload.size
    assert_equal 2, answer.educations.size
    question.update_attributes!(question_type: ProfileQuestion::Type::MULTI_STRING)
    assert_equal 0, question.profile_answers.reload.size
  end

  def test_after_destroy_updates_answer_text
    question = profile_questions(:multi_education_q)
    answer = profile_answers(:profile_answers_1)
    assert_equal 2, answer.educations.size
    assert_equal "American boys school, Science, Mechanical\n Indian college, Arts, Computer Engineering", answer.answer_text
    educations(:edu_2).destroy
    assert_equal 1, answer.reload.educations.size
    assert_equal "American boys school, Science, Mechanical", answer.answer_text
    assert_equal 2, question.profile_answers.reload.size
  end
end
