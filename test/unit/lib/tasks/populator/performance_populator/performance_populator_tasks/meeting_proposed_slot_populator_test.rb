require_relative './../../../../../../test_helper'

class MeetingProposedSlotPopulatorTest < ActiveSupport::TestCase
  def test_add_remove_meeting_proposed_slots
    organization = programs(:org_primary)
    program = organization.programs.first
    to_add_ids = program.meeting_requests.accepted.pluck(:id)
    to_del_ids = []
    5.times do
      meeting_request = create_meeting_request(program: program, status: AbstractRequest::Status::ACCEPTED)
      create_meeting_proposed_slot({meeting_request_id: meeting_request.id})
      to_del_ids << meeting_request.id
    end
    populator_add_and_remove_objects("meeting_proposed_slot", "meeting_request", to_add_ids, to_del_ids, {organization: organization, program: program, additional_populator_class_options: {percents_ary: [100], counts_ary: [1]}})
  end
end