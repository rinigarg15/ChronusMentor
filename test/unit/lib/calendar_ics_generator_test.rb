require_relative './../../test_helper.rb'

class CalendarIcsGeneratorTest < ActionView::TestCase

  def test_generate_ics_calendar
    current_time = Time.new(2018,06,27,12,00,00)
    Timecop.freeze(current_time) do 
      event = program_events(:birthday_party)
      event.start_time = current_time.utc
      event.created_at = current_time.utc
      event.save!
      user = mentor = users(:robert)
      ProgramEvent.any_instance.stubs(:get_description_for_calendar_event).returns("d\n")
      calendar = "BEGIN:VCALENDAR\nPRODID;X-RICAL-TZSOURCE=TZINFO:-//com.denhaven2/NONSGML ri_cal gem//EN\nCALSCALE:GREGORIAN\nVERSION:2.0\nMETHOD:REQUEST\nBEGIN:VEVENT\nCREATED;VALUE=DATE-TIME:20180627T063000Z\nSTATUS:CONFIRMED\nDTSTART;VALUE=DATE-TIME:20180627T010000Z\nTRANSP:OPAQUE\nDTSTAMP;VALUE=DATE-TIME:20180627T063000Z\nLAST-MODIFIED;VALUE=DATE-TIME:20180627T063000Z\nATTENDEE;CN=robert user;CUTYPE=INDIVIDUAL;PARTSTAT=NEEDS-ACTION;ROLE=REQ-\n PARTICIPANT:mailto:userrobert@example.com\nUID:program_event_#{DateTime.localize(Time.now.utc, format: :ics_full_time)}@chronus.com\nDESCRIPTION:d\\n\nSUMMARY:Birthday Party\nORGANIZER;CN=Apollo Services:mailto:event-calendar-assistant-dev+79B657EC\n 73F02F99@testmg.realizegoal.com\nLOCATION:chennai\\, tamilnadu\\, india\nEND:VEVENT\nEND:VCALENDAR\n"
      calendar2 = CalendarIcsGenerator.generate_ics_calendar(event, user: user)
      assert_equal calendar, calendar2
    end
  end

  def test_generate_ics_calendar_for_deletion
    event = program_events(:birthday_party)
    program_event_id = event.id
    start_time = event.start_time
    created_at = event.created_at
    title = event.get_titles_for_all_locales
    calendar = "BEGIN:VCALENDAR\nPRODID;X-RICAL-TZSOURCE=TZINFO:-//com.denhaven2/NONSGML ri_cal gem//EN\nCALSCALE:GREGORIAN\nVERSION:2.0\nMETHOD:CANCEL\nBEGIN:VEVENT\nSTATUS:CANCELLED\nDTSTART;VALUE=DATE-TIME:20180727T111036Z\nUID:program_event_20180627T164036@chronus.com\nSUMMARY:Birthday Party\nORGANIZER;CUTYPE=INDIVIDUAL;ROLE=REQ-PARTICIPANT:mailto:event-calendar-as\n sistant-dev+79B657EC73F02F99@testmg.realizegoal.com\nEND:VEVENT\nEND:VCALENDAR\n"
    generated_calendar = calendar = CalendarIcsGenerator.generate_ics_calendar_for_deletion(program_event_id: program_event_id, start_time: start_time, created_at: created_at, title: title).to_s
    assert_equal calendar, generated_calendar
  end

end
