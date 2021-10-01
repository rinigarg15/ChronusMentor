require_relative './../../../../test_helper'

class MeetingElasticsearchQueriesTest < ActiveSupport::TestCase

  def test_get_meeting_ids_by_conditions_empty_options_hash
    assert_equal_unordered Meeting.pluck(:id), Meeting.get_meeting_ids_by_conditions(active: true, not_cancelled: true)
    assert_equal_unordered [1, 2, 6, 7, 9, 10, 11], Meeting.get_meeting_ids_by_conditions(active: true, not_cancelled: true, program_id: programs(:albers).id)

    meeting = create_meeting(start_time: 2.days.from_now, end_time: 3.days.from_now)
    assert_equal 12, Meeting.all.size
    meeting.member_meetings.first.destroy
    reindex_documents(created: meeting)

    meetings = Meeting.get_meeting_ids_by_conditions(not_cancelled: true)
    assert_equal 11, meetings.size
  end

  def test_get_meeting_ids_by_conditions
    assert_equal_unordered [meetings(:upcoming_psg_mentor_psg_student).id, meetings(:past_psg_mentor_psg_student).id, meetings(:upcoming_psg_calendar_meeting).id, meetings(:psg_mentor_psg_student).id], Meeting.get_meeting_ids_by_conditions({active: true, not_cancelled: true, "attendees.id": members(:psg_mentor1).id})
    assert_empty Meeting.get_meeting_ids_by_conditions(active: true, not_cancelled: true, "attendees.id" => 90)
  end

  def test_get_meeting_ids_by_topic
    assert_equal [1, 2, 6], Meeting.get_meeting_ids_by_topic("Arbit", active: true, not_cancelled: true)
  end
end