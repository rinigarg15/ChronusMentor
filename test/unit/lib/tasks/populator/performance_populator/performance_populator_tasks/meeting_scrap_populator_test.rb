require_relative './../../../../../../test_helper'

class MeetingScrapPopulatorTest < ActiveSupport::TestCase
  def test_add_remove_meeting_scraps
    organization = programs(:org_primary)
    program = organization.programs.first
    to_add_ids = []
    5.times do
      meeting_request = create_meeting_request(program: program, status: AbstractRequest::Status::ACCEPTED)
      meeting = meeting_request.meeting
      to_add_ids << meeting.id
    end
    to_del_ids = []
    5.times do
      meeting_request = create_meeting_request(program: program, status: AbstractRequest::Status::ACCEPTED)
      meeting = meeting_request.meeting
      create_scrap(group: meeting)
      to_del_ids << meeting.id
    end
    populator_add_and_remove_objects("meeting_scrap", "meeting", to_add_ids, to_del_ids, {organization: organization, program: program, model: "scrap", additional_populator_class_options: {percents_ary: [100], counts_ary: [1]}})
  end
end