require_relative './../../../../../../test_helper'

class MeetingPopulatorTest < ActiveSupport::TestCase

  def test_add_remove_meetings_when_general_availability
    organization = programs(:org_primary)
    program = programs(:albers)
    to_add_ids = program.meeting_requests.accepted.pluck(:id)
    to_del_ids = 5.times.map { create_meeting_request(program: program, status: AbstractRequest::Status::ACCEPTED).id }
    populator_add_and_remove_objects("meeting", "meeting_request", to_add_ids, to_del_ids, organization: organization, program: program, calendar_time_available: false, additional_populator_class_options: { percents_ary: [100], counts_ary: [1], ignore_save_check: true } )
  end

  def test_add_remove_meetings_when_calendar_time_available
    organization = programs(:org_primary)
    program = programs(:albers)
    to_add_ids = program.meeting_requests.accepted.pluck(:id)
    to_del_ids = 5.times.map { create_meeting_request(program: program, status: AbstractRequest::Status::ACCEPTED).id }
    populator_add_and_remove_objects("meeting", "meeting_request", to_add_ids, to_del_ids, organization: organization, program: program, calendar_time_available: true, additional_populator_class_options: { percents_ary: [100], counts_ary: [1], ignore_save_check: true } )
  end
end