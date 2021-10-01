require_relative './../../../../../../test_helper'

class GroupMeetingPopulatorTest < ActiveSupport::TestCase
  def test_add_remove_group_meetings
    program = programs(:albers)
    to_add_group_ids = program.groups.pluck(:id).uniq.first(5)
    to_remove_group_ids = program.meetings.pluck(:group_id).uniq.last(5)
    populator_add_and_remove_objects("group_meeting", "program", to_add_group_ids, to_remove_group_ids, {program: program, model: "meeting"})
  end
end