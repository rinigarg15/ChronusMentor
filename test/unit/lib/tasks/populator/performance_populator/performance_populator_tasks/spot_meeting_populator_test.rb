require_relative './../../../../../../test_helper'

class SpotMeetingPopulatorTest < ActiveSupport::TestCase
  def test_add_spot_meetings
    program = programs(:albers)
    program.organization.members.update_all(:will_set_availability_slots => false)
    to_add_owner_ids = program.users.active.select{|user| user.is_student?}.collect(&:member_id)
    to_remove_owner_ids = program.meetings.pluck(:owner_id).uniq.last(5)
    populator_add_and_remove_objects("spot_meeting", "student", to_add_owner_ids, to_remove_owner_ids, {program: program, eligible_mentor: program.users.active.select{|user| user.is_mentor? && !user.member.will_set_availability_slots?}, model: "meeting"})
  end
end