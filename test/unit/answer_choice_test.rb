require_relative '../test_helper'

class AnswerChoiceTest < ActiveSupport::TestCase
  def test_validations
    ans_choice = AnswerChoice.new
    assert_false ans_choice.valid?
    assert_equal ["can't be blank"], ans_choice.errors.messages[:question_choice_id]
    assert_equal ["can't be blank"], ans_choice.errors.messages[:ref_obj]

    ans_choice.question_choice_id = 1
    ans_choice.ref_obj_id = 1
    ans_choice.ref_obj_type = "ProfileAnswer"
    assert ans_choice.valid?

    ans_choice.save!

    ans_choice_2 = AnswerChoice.new(question_choice_id: 1, ref_obj_id: 1, ref_obj_type: "ProfileAnswer")
    assert_false ans_choice_2.valid?
    assert_equal ["has already been taken"], ans_choice_2.errors.messages[:question_choice_id]

    ans_choice_2.ref_obj_id = 4
    assert ans_choice_2.valid?

    ans_choice_2.ref_obj_type = "CommonAnswer"
    assert ans_choice_2.valid?
  end

  def test_member_id
    profile_answer = ProfileAnswer.first
    answer_choice = AnswerChoice.new(ref_obj: profile_answer)
    assert_equal profile_answer.ref_obj_id, answer_choice.member_id
  end

  def test_bulk_create_initial_versions
    answer_choice = AnswerChoice.last
    answer_choice.versions.destroy_all
    assert_equal [], answer_choice.reload.versions
    assert_no_difference('AnswerChoiceVersion.count') do
      AnswerChoice.create_initial_versions_in_chunks(AnswerChoice.maximum(:id) + 10, AnswerChoice.maximum(:id) + 20)
    end
    assert_difference('AnswerChoiceVersion.count', 1) do
      AnswerChoice.create_initial_versions_in_chunks(answer_choice.id, answer_choice.id)
    end
    assert_equal 1, answer_choice.reload.versions.size
  end

  def test_create_initial_versions_in_chunks
    AnswerChoice.expects(:create_initial_versions_in_chunks).with(1000, 1999)
    AnswerChoice.expects(:create_initial_versions_in_chunks).with(2000, 2500)
    AnswerChoice.bulk_create_initial_versions(1000, 2500)
  end
end