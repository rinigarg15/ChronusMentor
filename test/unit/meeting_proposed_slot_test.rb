require_relative "./../test_helper.rb"

class MeetingProposedSlotTest < ActiveSupport::TestCase
  def test_validations
    proposed_slot = MeetingProposedSlot.new(meeting_request_id: 1, start_time: 15.minutes.since)
    assert_false proposed_slot.valid?
    assert proposed_slot.errors[:end_time]
    assert proposed_slot.errors[:proposer_id]
    proposed_slot = MeetingProposedSlot.new(meeting_request_id: 1, start_time: 45.minutes.since, end_time: 15.minutes.since, proposer_id: 1)
    assert proposed_slot.valid?
  end

  def test_meeting_request_association
    meeting_request = create_meeting_request
    proposed_slot = create_meeting_proposed_slot({meeting_request_id: meeting_request.id})
    assert_equal meeting_request, proposed_slot.meeting_request
  end

  def test_get_ics_file_url
    assert S3Helper.respond_to?(:embed_timestamp)
    assert SecureRandom.respond_to?(:hex)
    assert S3Helper.respond_to?(:transfer)
    meeting_request = create_meeting_request
    proposed_slot = create_meeting_proposed_slot({meeting_request_id: meeting_request.id})
    meeting = meeting_request.meeting
    Meeting.any_instance.expects(:update_meeting_time).once.returns(true)
    File.expects(:write).once.returns(true)
    S3Helper.expects(:embed_timestamp).once.returns("")
    S3Helper.expects(:transfer).once.returns("")
    proposed_slot.get_ics_file_url(meeting.participant_users.first)
  end

  def test_earliest_slots_scope
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, force_non_time_meeting: true,start_time: time, end_time: time + 30.minutes, owner_id: members(:mkr_student).id)
    meeting_request = meeting.meeting_request
    slot1 = create_meeting_proposed_slot({start_time: time + 3.days, end_time: time + 3.days + 30.minutes, meeting_request_id: meeting_request.id})
    slot2 = create_meeting_proposed_slot({start_time: time + 4.days, end_time: time + 3.days + 30.minutes, meeting_request_id: meeting_request.id})

    time = 3.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, force_non_time_meeting: true, start_time: time, end_time: time + 30.minutes, owner_id: members(:mkr_student).id)
    meeting_request = meeting.meeting_request
    slot3 = create_meeting_proposed_slot({start_time: time + 3.days, end_time: time + 3.days + 30.minutes, meeting_request_id: meeting_request.id})
    slot4 = create_meeting_proposed_slot({start_time: time + 4.days, end_time: time + 3.days + 30.minutes, meeting_request_id: meeting_request.id})
    assert_equal_unordered [slot1, slot3], MeetingProposedSlot.earliest_slots
  end
end
