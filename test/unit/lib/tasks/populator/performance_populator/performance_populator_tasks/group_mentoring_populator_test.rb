require_relative './../../../../../../test_helper'

class GroupMentoringMentorIntensivePopulatorTest < ActiveSupport::TestCase
  def test_group_mentoring
    program = programs(:albers)
    GroupMentoringMentorIntensivePopulator.new("group_mentoring_mentor_intensive", {parent: "program", percents_ary: [100], counts_ary: [1], common: {"group_mentoring_enabled?" => true}, args: {"mentor" => 8, "mentee" => 2}, program: program}).patch
    populator_object_save!(program.groups.reload.last)
    assert_equal 8, program.groups.last.mentor_memberships.pluck(:id).uniq.count
    assert_equal 2, program.groups.last.student_memberships.pluck(:id).uniq.count
    # GroupMentoringEqualMentorMenteePopulator.new("group_mentoring_equal_mentor_mentee", {parent: "program", percents_ary: [100], counts_ary: [1], common: {"group_mentoring_enabled?" => true}, args: {"mentor" => 5, "mentee" => 5}, program: program}).patch
    # populator_object_save!(program.groups.reload.last)

    # assert_equal 5, program.groups.last.mentor_memberships.pluck(:id).uniq.count
    # assert_equal 5, program.groups.last.student_memberships.pluck(:id).uniq.count
    # GroupMentoringMenteeIntensivePopulator.new("group_mentoring_mentee_intensive", {parent: "program", percents_ary: [100], counts_ary: [1], common: {"group_mentoring_enabled?" => true}, args: {"mentor" => 2, "mentee" => 8}, program: program}).patch
    # populator_object_save!(program.groups.reload.last)
    # assert_equal 2, program.groups.last.mentor_memberships.pluck(:id).uniq.count
    # assert_equal 8, program.groups.last.student_memberships.pluck(:id).uniq.count
    # GroupMentoringMentorIntensivePopulator.new("group_mentoring_mentor_intensive", {parent: "program", percents_ary: [100], counts_ary: [1], common: {"group_mentoring_enabled?" => true}, args: {"mentor" => 10, "mentee" => 2}, program: program}).patch
    # populator_object_save!(program.groups.reload.last)
    # assert_equal 10, program.groups.last.mentor_memberships.pluck(:id).uniq.count
    # assert_equal 2, program.groups.last.student_memberships.pluck(:id).uniq.count
    # GroupMentoringEqualMentorMenteePopulator.new("group_mentoring_equal_mentor_mentee", {parent: "program", percents_ary: [100], counts_ary: [1], common: {"group_mentoring_enabled?" => true}, args: {"mentor" => 10, "mentee" => 10}, program: program}).patch
    # populator_object_save!(program.groups.reload.last)
    # assert_equal 10, program.groups.last.mentor_memberships.pluck(:id).uniq.count
    # assert_equal 10, program.groups.last.student_memberships.pluck(:id).uniq.count
    # GroupMentoringMenteeIntensivePopulator.new("group_mentoring_mentee_intensive", {parent: "program", percents_ary: [100], counts_ary: [1], common: {"group_mentoring_enabled?" => true}, args: {"mentor" => 2, "mentee" => 10}, program: program}).patch
    # populator_object_save!(program.groups.reload.last)
    # assert_equal 2, program.groups.last.mentor_memberships.pluck(:id).uniq.count
    # assert_equal 10, program.groups.last.student_memberships.pluck(:id).uniq.count
  end
end