require_relative './../../../../test_helper'

class MeetingRequestElasticsearchQueriesTest < ActiveSupport::TestCase

  def test_get_es_meeting_requests
    program = programs(:albers)
    assert_empty MeetingRequest.get_es_meeting_requests( { created_at: 5.days.ago..3.days.ago, program_id: program.id }, ["sender_id", "receiver_id"]).to_a
    assert_empty MeetingRequest.get_es_meeting_requests( { created_at: 2.days.ago..3.days.since, program_id: 0 }, ["sender_id", "receiver_id"]).to_a
    assert_equal_unordered [[2, 3], [7, 8], [9, 3], [2, 26], [11, 8]], MeetingRequest.get_es_meeting_requests( { created_at: 2.days.ago..3.days.since, program_id: program.id }, ["sender_id", "receiver_id"]).to_a.collect { |entry| [entry.sender_id, entry.receiver_id] }

    mr = program.meeting_requests.active.first
    meeting_requests = MeetingRequest.get_es_meeting_requests( { created_at: (mr.created_at - 1.day).to_time..Time.now.to_time, program_id: program.id, status: AbstractRequest::Status::NOT_ANSWERED }, ["id"])
    assert meeting_requests.collect(&:id).include?(mr.id.to_s)
  end
end