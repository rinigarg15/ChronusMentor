require_relative './../../../../../../test_helper'

class ProfileAnswerPopulatorTest < ActiveSupport::TestCase
  def test_add_profile_answers
    program = programs(:albers)
    profile_answer_populator = ProfileAnswerPopulator.new("profile_answer", {parent: "member", percents_ary: [50, 25, 25], counts_ary: [3, 2, 1]})
    count = 1
    mentor_questions = program.profile_questions_for(RoleConstants::MENTOR_NAME).select { |q| q.non_default_type? && !q.file_type? }
    student_questions = program.profile_questions_for(RoleConstants::STUDENT_NAME).select { |q| q.non_default_type? && !q.file_type? }
    member_ids = program.mentor_users.active.first(5).collect(&:id)
    assert_difference "ProfileAnswer.count", member_ids.size * mentor_questions.size do
      profile_answer_populator.add_profile_answers(member_ids, count, {program: program, profile_question: mentor_questions})
    end
    populator_object_save!(ProfileAnswer.last)
    member_ids = program.student_users.active.first(5).collect(&:id)
    assert_difference "ProfileAnswer.count", member_ids.size * student_questions.size do
      profile_answer_populator.add_profile_answers(member_ids, count, {program: program, profile_question: student_questions})
    end
    populator_object_save!(ProfileAnswer.last)
  end

  def test_remove_profile_answers
    program = programs(:albers)
    profile_answer_populator = ProfileAnswerPopulator.new("profile_answer", {parent: "member", percents_ary: [50, 25, 25], counts_ary: [3, 2, 1]})
    count = 1
    member_ids = ProfileAnswer.first(5).collect(&:ref_obj_id).uniq
    assert_difference "ProfileAnswer.count", -(member_ids.size * count) do
      profile_answer_populator.remove_profile_answers(member_ids, count, {program: program})
    end
  end
end