require_relative './../../test_helper.rb'

class ExperienceObserverTest < ActiveSupport::TestCase
  def test_after_destroy_on_question_type_change
    question = profile_questions(:multi_experience_q)
    answer = profile_answers(:profile_answers_4)
    assert_equal 2, question.profile_answers.reload.size
    assert_equal 2, answer.experiences.size
    question.update_attributes!(question_type: ProfileQuestion::Type::MULTI_STRING)
    assert_equal 0, question.profile_answers.reload.size
  end

  def test_after_destroy_updates_answer_text
    question = profile_questions(:multi_experience_q)
    answer = profile_answers(:profile_answers_4)
    assert_equal 2, answer.experiences.size
    assert_equal "Lead Developer, Microsoft\n Chief Software Architect And Programming Lead, Mannar", answer.answer_text
    experiences(:exp_2).destroy
    assert_equal 1, answer.reload.experiences.size
    assert_equal "Lead Developer, Microsoft", answer.answer_text
    assert_equal 2, question.profile_answers.reload.size
  end
end
