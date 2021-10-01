class MeetingRequestObserver < ActiveRecord::Observer
  def after_create(meeting_request)
    meeting = meeting_request.get_meeting
    meeting_request.create_meeting_proposed_slots
    return if meeting_request.skip_observer || meeting.archived? || meeting_request.skip_email_notification
    Push::Base.queued_notify(PushNotification::Type::MEETING_REQUEST_CREATED, meeting_request)
    meeting_request_id = meeting_request.id
    MeetingRequest.delay(queue: DjQueues::HIGH_PRIORITY).send_meeting_request_sent_notification(meeting_request_id) if meeting.calendar_time_available?
    MeetingRequest.delay(queue: DjQueues::HIGH_PRIORITY).send_meeting_request_created_notification(meeting_request_id)
  end

  def after_update(meeting_request)
    return if meeting_request.skip_observer
    return if !meeting_request.saved_change_to_status? || meeting_request.closed?
    meeting = meeting_request.get_meeting
    meeting.false_destroy!(true) if meeting_request.withdrawn?
    meeting_request.student.withdraw_active_meeting_requests!(meeting.start_time) if meeting_request.accepted?
    return if meeting.archived? || meeting_request.skip_email_notification
    Push::Base.queued_notify(Push::Notifications::MeetingRequestPushNotification::ENABLED_NOTIFICATIONS_MAPPER[meeting_request.status], meeting_request) if Push::Notifications::MeetingRequestPushNotification::ENABLED_NOTIFICATIONS_MAPPER[meeting_request.status]
    meeting_request_id = meeting_request.id
    MeetingRequest.delay(queue: DjQueues::HIGH_PRIORITY).send_meeting_request_status_accepted_notification_to_self(meeting_request_id) if meeting.calendar_time_available? && meeting_request.accepted?
    MeetingRequest.delay(queue: DjQueues::HIGH_PRIORITY).send_meeting_request_status_changed_notification(meeting_request_id)
  end

end