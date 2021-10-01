require_relative './../test_helper.rb'

class MeetingRequestTest < ActiveSupport::TestCase
  def test_meeting_association
    meeting = create_meeting(force_non_time_meeting: true)
    assert_equal MeetingRequest.last, meeting.meeting_request
    meeting_request = MeetingRequest.last
    assert_no_difference "Meeting.count" do
      assert_difference "MeetingRequest.count", -1 do
        meeting_request.destroy
      end
    end
  end

  def test_has_many_member_meetings
    meeting = create_meeting(force_non_time_meeting: true)
    member_meetings = meeting.member_meetings
    meeting_request = MeetingRequest.last
    assert_equal member_meetings, meeting_request.member_meetings
  end

  def test_meeting_proposed_slot_association
    meeting_request = create_meeting_request
    slot_1 = create_meeting_proposed_slot({meeting_request_id: meeting_request.id})
    slot_2 = create_meeting_proposed_slot({meeting_request_id: meeting_request.id})
    slot_3 = create_meeting_proposed_slot({meeting_request_id: meeting_request.id})
    assert_equal [slot_1, slot_2, slot_3], meeting_request.reload.meeting_proposed_slots
    assert_difference "MeetingProposedSlot.count", -3 do
      assert_difference "MeetingRequest.count", -1 do
        meeting_request.destroy
      end
    end
  end

  def test_create_meeting_proposed_slots
    time = Time.now.utc + 2.days
    meeting_request = create_meeting_request
    meeting_request.proposed_slots_details_to_create = [OpenStruct.new(location: "chennai", start_time: time, end_time: time + 30.minutes)]
    assert_difference "MeetingProposedSlot.count", 1 do
      meeting_request.create_meeting_proposed_slots
    end
    assert_equal 1, meeting_request.reload.meeting_proposed_slots.size
    slot = meeting_request.meeting_proposed_slots[0]
    assert_equal time.to_i, slot.start_time.to_i
    assert_equal (time+30.minutes).to_i, slot.end_time.to_i
    assert_equal "chennai", slot.location
    assert_equal meeting_request.student.id, slot.proposer_id
  end

  def test_receiver_updated_time
    meeting_request = create_meeting_request
    slot_1 = create_meeting_proposed_slot({meeting_request_id: meeting_request.id})
    assert_false meeting_request.reload.receiver_updated_time?
    slot_2 = create_meeting_proposed_slot({meeting_request_id: meeting_request.id, proposer_id: meeting_request.mentor.id})
    assert_false meeting_request.reload.receiver_updated_time?
    slot_3 = create_meeting_proposed_slot({meeting_request_id: meeting_request.id, proposer_id: meeting_request.mentor.id, start_time: meeting_request.meeting.start_time})
    assert meeting_request.reload.receiver_updated_time?
  end

  def test_send_meeting_request_sent_notification
    chronus_s3_utils_stub

    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = meeting.meeting_request

    assert meeting.calendar_time_available?
    assert_false meeting.archived?
    assert_emails 1 do
      MeetingRequest.send_meeting_request_sent_notification(meeting_request.id)
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [meeting_request.student.email], email.to
    assert_equal "Your invitation for '#{meeting.topic}' has been sent", email.subject

    meeting.update_column(:calendar_time_available, false)
    assert_no_emails do
      MeetingRequest.send_meeting_request_sent_notification(meeting_request.id)
    end

    meeting.update_column(:calendar_time_available, true)
    Meeting.any_instance.expects(:archived?).returns(true)
    assert_no_emails do
      MeetingRequest.send_meeting_request_sent_notification(meeting_request.id)
    end

    assert_no_emails do
      MeetingRequest.send_meeting_request_sent_notification(0)
    end
  end

  def test_send_meeting_request_created_notification
    chronus_s3_utils_stub

    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = meeting.meeting_request

    assert meeting.calendar_time_available?
    assert_false meeting.archived?
    assert_emails 1 do
      MeetingRequest.send_meeting_request_created_notification(meeting_request.id)
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [meeting_request.mentor.email], email.to
    assert_equal "General Topic: You received a request for a meeting from #{meeting_request.student.name}", email.subject

    assert meeting.calendar_time_available?
    ChronusMailer.expects(:meeting_request_created_notification).returns(stub(:deliver_now))
    MeetingRequest.send_meeting_request_created_notification(meeting_request.id)

    meeting.update_column(:calendar_time_available, false)
    ChronusMailer.expects(:meeting_request_created_notification_non_calendar).returns(stub(:deliver_now))
    MeetingRequest.send_meeting_request_created_notification(meeting_request.id)

    meeting.update_column(:calendar_time_available, true)
    Meeting.any_instance.expects(:archived?).returns(true)
    assert_no_emails do
      MeetingRequest.send_meeting_request_created_notification(meeting_request.id)
    end

    assert_no_emails do
      MeetingRequest.send_meeting_request_created_notification(0)
    end
  end

  def test_send_meeting_request_status_accepted_notification_to_self
    chronus_s3_utils_stub

    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = meeting.meeting_request
    meeting_request_id = meeting_request.id

    assert_no_emails do
      MeetingRequest.send_meeting_request_status_accepted_notification_to_self(meeting_request_id)
    end

    assert_false meeting.archived?
    assert meeting.calendar_time_available?
    meeting_request.update_column(:status, AbstractRequest::Status::ACCEPTED)
    ChronusMailer.stubs(:email_template_disabled?).returns(false)
    assert_emails do
      MeetingRequest.send_meeting_request_status_accepted_notification_to_self(meeting_request_id)
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [meeting_request.mentor.email], email.to
    assert_equal "Confirmation: #{meeting.topic}", email.subject

    meeting.update_column(:calendar_time_available, false)
    assert_no_emails do
      MeetingRequest.send_meeting_request_status_accepted_notification_to_self(meeting_request_id)
    end

    meeting.update_column(:calendar_time_available, true)
    Meeting.any_instance.expects(:archived?).returns(true)
    assert_no_emails do
      MeetingRequest.send_meeting_request_status_accepted_notification_to_self(meeting_request_id)
    end

    assert_no_emails do
      MeetingRequest.send_meeting_request_status_accepted_notification_to_self(0)
    end
  end

  def test_send_meeting_request_status_changed_notification
    chronus_s3_utils_stub

    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = meeting.meeting_request

    assert meeting_request.active?
    assert_no_emails do
      MeetingRequest.send_meeting_request_status_changed_notification(meeting_request.id)
    end

    assert_false meeting_request.closed?
    assert_false meeting.archived?
    meeting_request.update_column(:status, AbstractRequest::Status::ACCEPTED)
    assert_false meeting_request.active?
    ChronusMailer.stubs(:email_template_disabled?).returns(false)
    assert_emails do
      MeetingRequest.send_meeting_request_status_changed_notification(meeting_request.id)
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [meeting_request.student.email], email.to
    assert_equal "Accepted: #{meeting.topic}", email.subject

    assert meeting.calendar_time_available?
    ChronusMailer.expects(:meeting_request_status_accepted_notification).returns(stub(:deliver_now))
    MeetingRequest.send_meeting_request_status_changed_notification(meeting_request.id)

    meeting.update_column(:calendar_time_available, false)
    ChronusMailer.expects(:meeting_request_status_accepted_notification_non_calendar).returns(stub(:deliver_now))
    MeetingRequest.send_meeting_request_status_changed_notification(meeting_request.id)

    meeting_request.update_column(:status, AbstractRequest::Status::REJECTED)
    ChronusMailer.expects(:meeting_request_status_declined_notification_non_calendar).returns(stub(:deliver_now))
    MeetingRequest.send_meeting_request_status_changed_notification(meeting_request.id)

    meeting_request.update_column(:status, AbstractRequest::Status::WITHDRAWN)
    ChronusMailer.expects(:meeting_request_status_withdrawn_notification_non_calendar).returns(stub(:deliver_now))
    MeetingRequest.send_meeting_request_status_changed_notification(meeting_request.id)

    assert_no_emails do
      MeetingRequest.send_meeting_request_status_changed_notification(0)
    end
  end

  def test_update_status
    time = 2.days.from_now
    meeting = create_meeting(force_non_time_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = meeting.meeting_request
    assert_equal AbstractRequest::Status::NOT_ANSWERED, meeting_request.status
    meeting_request.update_status!(users(:f_mentor), AbstractRequest::Status::ACCEPTED, member: members(:f_mentor), program: programs(:albers), rejection_type: AbstractRequest::Rejection_type::BUSY)
    assert_equal AbstractRequest::Status::ACCEPTED, meeting_request.status
    assert_equal MemberMeeting::ATTENDING::YES, meeting_request.member_meetings.find_by!(member_id: members(:f_mentor)).attending
    meeting_request.reload
    assert_equal AbstractRequest::Rejection_type::BUSY, meeting_request.rejection_type

    assert_no_difference "MemberMeeting.count" do
      assert_difference "Meeting.count", -1 do
        meeting_request.update_status!(users(:f_mentor), AbstractRequest::Status::WITHDRAWN, member: members(:f_mentor), program: programs(:albers))
      end
    end

    assert_false meeting.reload.active?
    assert_equal AbstractRequest::Status::WITHDRAWN, meeting_request.reload.status
  end

  def test_update_status_with_reject_notes
    time = 2.days.from_now
    meeting = create_meeting(force_non_time_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = meeting.meeting_request
    assert_equal AbstractRequest::Status::NOT_ANSWERED, meeting_request.status
    meeting_request.update_status!(users(:f_mentor), AbstractRequest::Status::REJECTED, member: members(:f_mentor), program: programs(:albers), response_text: "I will not be able to make it")
    assert_equal "I will not be able to make it", meeting_request.response_text
    assert_equal AbstractRequest::Status::REJECTED, meeting_request.status
  end

  def test_get_meeting
    meeting = create_meeting(force_non_time_meeting: true)
    meeting_request = meeting.meeting_request

    assert_equal meeting, meeting_request.get_meeting

    meeting.update_attributes!(active: false)
    assert_equal meeting, meeting_request.reload.get_meeting
  end

  def test_latest_first
    MeetingRequest.destroy_all
    meeting1 = create_meeting(force_non_time_meeting: true)
    meeting2 = create_meeting(force_non_group_meeting: true)
    assert_equal [meeting2.meeting_request, meeting1.meeting_request], MeetingRequest.latest_first
    meeting3 = create_meeting(force_non_group_meeting: true)
    assert_equal [meeting3.meeting_request, meeting2.meeting_request, meeting1.meeting_request], MeetingRequest.latest_first
  end

  def test_export_to_stream_csv
    chronus_s3_utils_stub
    time = Time.now
    meeting_request1 = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes).meeting_request
    meeting_request2 = create_meeting(force_non_time_meeting: true, start_time: time, end_time: time + 30.minutes).meeting_request
    csv_stream = StringIO.new
    meeting_requests = MeetingRequest.where(id: [meeting_request1.id, meeting_request2.id])
    MeetingRequestReport::CSV.export_to_stream(csv_stream, meeting_requests, AbstractRequest::Status::STATE_TO_STRING[AbstractRequest::Status::ACCEPTED], members(:f_admin))
    csv_records = csv_stream.string.split("\n")
    assert_equal ["Request ID", "Sender", "Sender Email", "Recipient", "Recipient Email", "Topic", "Description", "Proposed Time", "Location", "Sent"], csv_records[0].split(",")
    slot_meeting_details = csv_records[1].split(",")
    ga_meeting_details = csv_records[2].split(",")
    assert_equal ["mkr_student madankumarrajan", "mkr@example.com", "Good unique name", "robert@example.com", "General Topic", "This is a description of the meeting"], slot_meeting_details[1..6]
    assert_equal ["mkr_student madankumarrajan", "mkr@example.com", "Good unique name", "robert@example.com", "General Topic", "This is a description of the meeting"], ga_meeting_details[1..6]
    assert slot_meeting_details[7].present?
    assert slot_meeting_details[8].present?
    assert_equal "\"\"", ga_meeting_details[7]
    assert_equal "\"\"", ga_meeting_details[8]
  end

  def test_export_to_stream_csv_with_different_time_zone
    chronus_s3_utils_stub
    new_time = Time.local(2012, 9, 1, 12, 30, 0)
    Timecop.travel(new_time)
    time = Time.now.utc
    meeting_request1 = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes).meeting_request
    meeting_request2 = create_meeting(force_non_time_meeting: true, start_time: time, end_time: time + 30.minutes).meeting_request
    initial_meeting_start_time = meeting_request1.get_meeting.start_time.utc
    member = members(:f_admin)
    member.update_attributes!(time_zone: "Asia/Kolkata")
    expected_meeting_start_time = initial_meeting_start_time + 30.minutes + 5.hours
    assert_equal "IST", member.short_time_zone
    csv_stream = StringIO.new
    meeting_requests = MeetingRequest.where(id: [meeting_request1.id, meeting_request2.id])
    MeetingRequestReport::CSV.export_to_stream(csv_stream, meeting_requests, AbstractRequest::Status::STATE_TO_STRING[AbstractRequest::Status::NOT_ANSWERED], member)
    csv_records = csv_stream.string.split("\n")
    assert_equal ["Request ID", "Sender", "Sender Email", "Recipient", "Recipient Email", "Topic", "Description", "Proposed Time", "Location", "Sent"], csv_records[0].split(",")
    assert_match /IST/, csv_records[2]
    assert_match /#{expected_meeting_start_time.strftime("%I:%M %P")}/, csv_records[2]

    member.update_attributes!(time_zone: "Asia/Karachi")
    assert_equal "PKT", member.short_time_zone
    expected_meeting_start_time = initial_meeting_start_time + 5.hours
    csv_stream = StringIO.new
    meeting_requests = MeetingRequest.where(id: [meeting_request1.id, meeting_request2.id])
    MeetingRequestReport::CSV.export_to_stream(csv_stream, meeting_requests, AbstractRequest::Status::STATE_TO_STRING[AbstractRequest::Status::WITHDRAWN], member)
    csv_records = csv_stream.string.split("\n")
    assert_match /PKT/, csv_records[2]
    assert_match /#{expected_meeting_start_time.strftime("%I:%M %P")}/, csv_records[2]
    Timecop.return
  end

  def test_csv_export_rejected_and_closed_requests
    chronus_s3_utils_stub
    time = Time.now
    meeting_request = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes).meeting_request
    meeting_request.update_attributes!(response_text: "response text")
    csv_stream = StringIO.new
    meeting_requests = MeetingRequest.where(id: [meeting_request.id])
    MeetingRequestReport::CSV.export_to_stream(csv_stream, meeting_requests, AbstractRequest::Status::STATE_TO_STRING[AbstractRequest::Status::REJECTED], members(:f_admin))

    csv_records = csv_stream.string.split("\n")
    assert_equal ["Request ID", "Sender", "Sender Email", "Recipient", "Recipient Email", "Topic", "Description", "Proposed Time", "Location", "Sent", "Reason for Decline"], csv_records[0].split(",")
    assert_equal "response text", csv_records[1].split(",").last

    csv_stream = StringIO.new
    MeetingRequestReport::CSV.export_to_stream(csv_stream, meeting_requests, AbstractRequest::Status::STATE_TO_STRING[AbstractRequest::Status::CLOSED], members(:f_admin))
    csv_records = csv_stream.string.split("\n")
    assert_equal ["Request ID", "Sender", "Sender Email", "Recipient", "Recipient Email", "Topic", "Description", "Proposed Time", "Location", "Sent", "Reason for Closure"], csv_records[0].split(",")
    assert_equal "response text", csv_records[1].split(",").last
  end

  def test_send_meeting_request_reminder
    chronus_s3_utils_stub
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    MeetingRequest.destroy_all
    time = Time.now.utc
    meeting_request1 = create_meeting(force_non_group_meeting: true, start_time: time + 1.day, end_time: time + 1.day + 30.minutes).meeting_request
    meeting_request1.update_attributes(:created_at => time - 7.days - 15.minutes)
    meeting_request2 = create_meeting(force_non_time_meeting: true, start_time: time + 1.day, end_time: time + 1.day + 30.minutes).meeting_request
    meeting_request2.update_attributes(:created_at => time - 8.days - 15.minutes)
    meeting_request3 = create_meeting(force_non_time_meeting: true, start_time: time + 1.day, end_time: time + 1.day + 30.minutes).meeting_request
    meeting_request3.update_attributes(:created_at => time - 6.days - 15.minutes)
    programs(:albers).update_attribute(:needs_meeting_request_reminder, false)
    programs(:albers).update_attribute(:meeting_request_reminder_duration, 7)
    Push::Base.expects(:queued_notify).never
    assert_emails(0) do
      MeetingRequest.send_meeting_request_reminders
    end
    programs(:albers).update_attribute(:needs_meeting_request_reminder, true)
    programs(:albers).update_attribute(:meeting_request_reminder_duration, 90)
    assert_emails(0) do
      MeetingRequest.send_meeting_request_reminders
    end
    programs(:albers).update_attribute(:needs_meeting_request_reminder, true)
    programs(:albers).update_attribute(:meeting_request_reminder_duration, 7)
    Push::Base.expects(:queued_notify).once
    assert_emails(1) do
      MeetingRequest.send_meeting_request_reminders
    end
    assert_not_nil meeting_request1.reload.reminder_sent_time
    Push::Base.expects(:queued_notify).never
    assert_emails(0) do
      MeetingRequest.send_meeting_request_reminders
    end
    Push::Base.expects(:queued_notify).never
    meeting_request4 = create_meeting(force_non_time_meeting: true, start_time: time - 1.day, end_time: time - 1.day + 30.minutes).meeting_request
    meeting_request4.update_attributes(:created_at => time - 7.days - 15.minutes)
    meeting_request4.get_meeting.update_attributes(:calendar_time_available => true)
    Push::Base.expects(:queued_notify).never
    assert_emails(0) do
      MeetingRequest.send_meeting_request_reminders
    end
    meeting_request4.get_meeting.update_attributes(:calendar_time_available => false)
    Push::Base.expects(:queued_notify).once
    assert_emails(1) do
      MeetingRequest.send_meeting_request_reminders
    end
    meeting_request3.update_attributes(:created_at => time - 7.days - 15.minutes)
  end

  def test_get_meeting_requests
    program = programs(:albers)
    time = 2.days.from_now
    MeetingRequest.destroy_all
    chronus_s3_utils_stub
    meeting_request1 = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes).meeting_request
    meeting_request2 = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes).meeting_request
    meeting_request3 = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes).meeting_request
    meeting_request1.update_attributes!(created_at: DateTime.new(2010))
    meeting_request2.update_attributes!(created_at: DateTime.new(2000), status: AbstractRequest::Status::ACCEPTED)
    meeting_request3.update_attributes!(created_at: DateTime.new(2000), status: AbstractRequest::Status::REJECTED)

    details = MeetingRequest.get_meeting_requests(program, {})
    assert_equal_unordered [meeting_request1, meeting_request2, meeting_request3], details[:meeting_requests]
    assert_nil details[:start_time]
    assert_nil details[:end_time]

    details = MeetingRequest.get_meeting_requests(program, {params: {list: :active}})
    assert_equal_unordered [meeting_request1], details[:meeting_requests]
    assert_nil details[:start_time]
    assert_nil details[:end_time]

    details = MeetingRequest.get_meeting_requests(program, {params: {search_filters: {expiry_date: "01/01/2005 - 10/23/2015"}}})
    assert_equal_unordered [meeting_request1], details[:meeting_requests]
    assert_equal DateTime.new(2005, 1, 1, 0, 0, 0).to_s, details[:start_time].to_s
    assert_equal DateTime.new(2015, 10, 23, 23, 59, 59).to_s, details[:end_time].to_s

    details = MeetingRequest.get_meeting_requests(program, {params: {list: :accepted, search_filters: {expiry_date: "01/01/1999 - 1/1/2001"}}})
    assert_equal_unordered [meeting_request2], details[:meeting_requests]
    assert_equal DateTime.new(1999, 1, 1, 0, 0, 0).to_s, details[:start_time].to_s
    assert_equal DateTime.new(2001, 1, 1, 23, 59, 59).to_s, details[:end_time].to_s

    assert_permission_denied do
      MeetingRequest.get_meeting_requests(program, {params: {list: :something, search_filters: {expiry_date: "01/01/1999 - 1/1/2001"}}})
    end
  end

  def test_to_or_by_user_scope
    assert_difference "MeetingRequest.to_or_by_user(users(:f_mentor)).count", 1 do
      assert_difference "MeetingRequest.to_or_by_user(users(:f_student)).count", 1 do
        meeting_request = create_meeting_request
        assert_equal users(:f_mentor), meeting_request.mentor
        assert_equal users(:f_student), meeting_request.student
      end
    end
  end

  def test_to_be_closed_scope
    program = programs(:albers)
    program.update_attribute :meeting_request_auto_expiration_days, 11

    assert_equal program.meeting_requests.to_be_closed.size, 0

    program.meeting_requests[0..1].each do |mr|
      mr.update_attribute :created_at, 12.days.ago
    end

    assert_equal program.meeting_requests.to_be_closed.size, 2
  end

  def test_close_request
    program = programs(:albers)
    program.update_attribute(:meeting_request_auto_expiration_days, 11)
    mr = program.meeting_requests.last

    mr.stubs(:close!).with("This request was closed automatically since the mentor did not respond within 11 days.").at_least(1)
    mr.close_request!
  end

  def test_skip_email_notification
    meeting_request = create_meeting_request
    assert meeting_request.active?
    assert_difference "ActionMailer::Base.deliveries.count", 1 do
      meeting_request.status = AbstractRequest::Status::ACCEPTED
      meeting_request.save
    end
    meeting_request = create_meeting_request
    assert meeting_request.active?
    assert_no_difference "ActionMailer::Base.deliveries.count" do
      meeting_request.skip_email_notification = true
      meeting_request.status = AbstractRequest::Status::ACCEPTED
      meeting_request.save
    end
  end

  def test_notify_expired_meeting_requests
    program = programs(:albers)
    program.update_attribute :meeting_request_auto_expiration_days, 11

    assert_equal program.meeting_requests.to_be_closed.size, 0
    assert_no_emails do
      MeetingRequest.notify_expired_meeting_requests
    end

    program.meeting_requests[0..1].each do |mr|
      mr.update_attribute :created_at, 12.days.ago
    end
    assert_equal program.meeting_requests.to_be_closed.size, 2
    assert_emails(2) do
      MeetingRequest.notify_expired_meeting_requests
    end
  end

  def test_get_meeting_proposed_slots
    meeting_request = create_meeting_request
    assert_equal [[meeting_request.get_meeting], false], meeting_request.get_meeting_proposed_slots
    proposed_slot = create_meeting_proposed_slot({meeting_request_id: meeting_request.id})
    assert_equal [[proposed_slot], true], meeting_request.reload.get_meeting_proposed_slots
  end
end