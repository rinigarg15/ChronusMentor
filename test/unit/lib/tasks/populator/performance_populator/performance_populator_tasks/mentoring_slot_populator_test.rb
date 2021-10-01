require_relative './../../../../../../test_helper'

class MentoringSlotPopulatorTest < ActiveSupport::TestCase
  def test_add_mentoring_slots
    program = programs(:albers)
    to_add_member_ids = program.users.active.select{|user| user.is_mentor? && user.member.will_set_availability_slots?}.collect(&:member_id).first(5)
    to_remove_member_ids = program.mentoring_slots.pluck(:member_id).uniq.first(5)
    populator_add_and_remove_objects("mentoring_slot", "mentor", to_add_member_ids, to_remove_member_ids, {program: program, students: program.users.active.select{|user| user.is_student?}})
  end
end