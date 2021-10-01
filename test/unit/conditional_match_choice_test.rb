require_relative '../test_helper'

class ConditionalMatchChoiceTest < ActiveSupport::TestCase
  def test_validations
    cmc = ConditionalMatchChoice.new
    assert_false cmc.valid?
    assert_equal ["can't be blank"], cmc.errors.messages[:profile_question_id]
    assert_equal ["can't be blank"], cmc.errors.messages[:question_choice_id]

    question = profile_questions(:profile_questions_8)
    conditional_question = profile_questions(:profile_questions_9)
    question.conditional_question = conditional_question
    question.save!

    cmc.profile_question = question
    cmc.question_choice = question_choices(:nch_single_choice_q1)
    assert_false cmc.valid?
    assert_equal ["doesn't belong to the conditional question"], cmc.errors.messages[:question_choice]

    cmc.question_choice = conditional_question.question_choices.first
    assert cmc.valid?
  end
end