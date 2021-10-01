require_relative './../../test_helper.rb'

class AnswerChoiceObserverTest < ActiveSupport::TestCase

  def test_after_destroy
    assert_difference "ProfileAnswer.count", -1 do
      assert_difference "QuestionChoice.count", -1 do
        assert_difference "AnswerChoice.count", -1 do
          question_choices(:single_choice_q_1).destroy
        end
      end     
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      profile_answers(:single_choice_ans_1).reload
    end
    answer_choices(:answer_choices_2).mark_for_destruction
    assert_no_difference "ProfileAnswer.count" do
      assert_no_difference "QuestionChoice.count" do
        assert_difference "AnswerChoice.count", -1 do
          answer_choices(:answer_choices_2).destroy
        end
      end
    end
  end

  def test_after_destroy_skip_parent_destroy
    profile_answer = answer_choices(:answer_choices_2).ref_obj
    assert_equal 1, profile_answer.answer_choices.count
    answer_choices(:answer_choices_2).skip_parent_destroy = true
    assert_no_difference "ProfileAnswer.count" do
      assert_no_difference "QuestionChoice.count" do
        assert_difference "AnswerChoice.count", -1 do
          answer_choices(:answer_choices_2).destroy
        end
      end
    end
    assert_equal 0, profile_answer.reload.answer_choices.count
  end

end
