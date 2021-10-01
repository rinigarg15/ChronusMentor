require_relative './../test_helper.rb'

class CalendarSyncRsvpLogsTest < ActiveSupport::TestCase
  
  def test_validations
    sync_log = CalendarSyncRsvpLogs.new

    assert_false sync_log.valid?
    assert_equal ["can't be blank"], sync_log.errors[:event_id]
    assert_equal ["can't be blank"], sync_log.errors[:notification_id]

    sync_log.event_id = "event id"
    sync_log.notification_id = 10

    assert sync_log.valid?
  end

  def test_create_rsvp_sync_log
    event1 = get_calendar_event_resource({id: "calendar_event_id_1"})
    event2 = get_calendar_event_resource({id: "calendar_event_id_2", recurring_event_id: "recurring_event_id"})

    calendar_events_1 = [event1]
    calendar_events_2 = [event1, event2]

    assert_difference "CalendarSyncRsvpLogs.count", 0 do
      CalendarSyncRsvpLogs.create_rsvp_sync_log([])
    end

    assert_difference "CalendarSyncRsvpLogs.count", 1 do
      CalendarSyncRsvpLogs.create_rsvp_sync_log(calendar_events_1)
    end

    sync_log_1 = CalendarSyncRsvpLogs.last

    assert_equal 1, sync_log_1.notification_id
    assert_equal "calendar_event_id_1", sync_log_1.event_id
    assert_nil sync_log_1.recurring_event_id
    assert_equal_hash({"robert@example.com" => "accepted", "mkr@example.com" => "declined"}, sync_log_1.rsvp_details)

    assert_difference "CalendarSyncRsvpLogs.count", 2 do
      CalendarSyncRsvpLogs.create_rsvp_sync_log(calendar_events_2)
    end

    sync_log_2 = CalendarSyncRsvpLogs.last(2).first

    assert_equal 2, sync_log_2.notification_id
    assert_equal "calendar_event_id_1", sync_log_2.event_id
    assert_nil sync_log_2.recurring_event_id
    assert_equal_hash({"robert@example.com" => "accepted", "mkr@example.com" => "declined"}, sync_log_2.rsvp_details)

    sync_log_3 = CalendarSyncRsvpLogs.last(2).last

    assert_equal 2, sync_log_3.notification_id
    assert_equal "calendar_event_id_2", sync_log_3.event_id
    assert_equal "recurring_event_id", sync_log_3.recurring_event_id
    assert_equal_hash({"robert@example.com" => "accepted", "mkr@example.com" => "declined"}, sync_log_3.rsvp_details)

    event1.attendees = nil

    assert_difference "CalendarSyncRsvpLogs.count", 1 do
      CalendarSyncRsvpLogs.create_rsvp_sync_log(calendar_events_1)
    end

    sync_log_4 = CalendarSyncRsvpLogs.last

    assert_equal 3, sync_log_4.notification_id
    assert_equal "calendar_event_id_1", sync_log_4.event_id
    assert_nil sync_log_4.recurring_event_id
    assert_equal_hash({}, sync_log_4.rsvp_details)
  end
end