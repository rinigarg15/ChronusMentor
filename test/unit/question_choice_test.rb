require_relative '../test_helper'

class QuestionChoiceTest < ActiveSupport::TestCase
  def test_validations
    qc = QuestionChoice.new
    assert_false qc.valid?
    assert_equal ["can't be blank"], qc.errors.messages[:text]
    assert_equal ["can't be blank"], qc.errors.messages[:ref_obj]

    qc.text = "random"
    qc.ref_obj = ProfileQuestion.find(1)
    assert qc.valid?

    qc.save!

    qc_2 = QuestionChoice.new(text: "random", ref_obj_id: 1, ref_obj_type: "ProfileQuestion")
    assert_false qc_2.valid?
    assert_equal ["has already been taken"], qc_2.errors.messages[:text]

    qc_2.ref_obj_id = 2
    assert qc_2.valid?

    qc_2.ref_obj_id = 1
    assert_false qc_2.valid?

    qc_2.ref_obj_type = "CommonQuestion"
    assert qc_2.valid?
  end

  def test_cleanup_duplicate_other_choices
    pq = profile_questions(:single_choice_q)
    pq.update_attributes!(allow_other_option: true)
    pa1 = profile_answers(:single_choice_ans_1)
    pa2 = profile_answers(:single_choice_ans_2)
    first_duplicate = pq.question_choices.create!(text: "Duplicate Other", is_other: true)
    pa1.answer_value = {answer_text: "Duplicate Other", question: pq}
    pa1.save!
    second_duplicate = pq.question_choices.build(text: "Duplicate Other", is_other: true)
    second_duplicate.save(validate: false)
    pa2.answer_value = {answer_text: "Duplicate Other", question: pq}
    pa2.save!
    pa2.answer_choices.first.update_attributes!(question_choice_id: second_duplicate.id)
    assert_equal [first_duplicate.id], pa1.answer_choices.collect(&:question_choice_id)
    assert_equal [second_duplicate.id], pa2.answer_choices.collect(&:question_choice_id)
    QuestionChoice.cleanup_duplicate_other_choices([pq.id])
    assert_equal [first_duplicate.id], pa1.answer_choices.reload.collect(&:question_choice_id)
    assert_equal [first_duplicate.id], pa2.answer_choices.reload.collect(&:question_choice_id)
    assert_raise ActiveRecord::RecordNotFound do
      second_duplicate.reload
    end
  end

  def test_user_search_activity_association
    question_choice = question_choices(:student_multi_choice_q_1)
    user_search_activities = [user_search_activities(:user_search_activity_2)]
    assert_equal user_search_activities, question_choice.user_search_activities
    assert_no_difference "UserSearchActivity.count" do
      assert_difference "QuestionChoice.count", -1 do
        question_choice.destroy
      end
    end
    assert_nil user_search_activities(:user_search_activity_2).reload.question_choice
  end

  def test_preference_based_mentor_lists
    qc = question_choices(:question_choices_52)
    assert_difference 'PreferenceBasedMentorList.count' do
      qc.preference_based_mentor_lists.create!(user: User.first, profile_question: ProfileQuestion.first, weight: 0.55)
    end

    assert_equal 0.55, qc.preference_based_mentor_lists.last.weight

    assert_difference 'PreferenceBasedMentorList.count', -1 do
      qc.destroy
    end    
  end
end
