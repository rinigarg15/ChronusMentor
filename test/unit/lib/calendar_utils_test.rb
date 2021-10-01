require_relative './../../test_helper.rb'

class CalendarUtilsTest < ActionView::TestCase

  def test_match_organizer_email
    assert_nil CalendarUtils.match_organizer_email("random@example.com", APP_CONFIG[:reply_to_calendar_notification])
    assert_nil CalendarUtils.match_organizer_email("event-calendar-assistant-dev@testmg.realizegoal.com", APP_CONFIG[:reply_to_program_event_calendar_notification])
    assert_nil CalendarUtils.match_organizer_email("calendar-assistant-dev+123@rrr.realizegoal.com", APP_CONFIG[:reply_to_calendar_notification])
    matched_meeting = CalendarUtils.match_organizer_email("calendar-assistant-dev+123@testmg.realizegoal.com", APP_CONFIG[:reply_to_calendar_notification])
    matched_program_event = CalendarUtils.match_organizer_email("event-calendar-assistant-dev+456@testmg.realizegoal.com", APP_CONFIG[:reply_to_program_event_calendar_notification])
    assert_equal "123", matched_meeting[:klass_id]
    assert_equal "456", matched_program_event[:klass_id]
  end

  def test_get_calendar_event_uid
    program_event = program_events(:birthday_party)
    created_at = DateTime.localize(program_event.created_at.utc, format: :ics_full_time)
    assert_equal "program_event_#{created_at}@chronus.com", CalendarUtils.get_calendar_event_uid(program_event)
  end

end