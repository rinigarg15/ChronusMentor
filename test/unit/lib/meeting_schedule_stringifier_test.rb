require_relative './../../test_helper.rb'

class MeetingScheduleStringifierTest < ActiveSupport::TestCase

  def test_integrity
    assert_gem_version "ice_cube", "0.11.3", "Handle ice_cube_overrides.rb and meeting_schedule_stringifier.rb!"
  end

  def test_stringify
    Meeting.all.each do |meeting|
      assert_equal MeetingScheduleStringifier.new(meeting).stringify, meeting.schedule.to_s
    end
  end

  def test_stringify_with_exception
    daily_meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    daily_meeting.add_exception_rule_at(daily_meeting.occurrences.first.start_time.to_s)
    assert_equal MeetingScheduleStringifier.new(daily_meeting).stringify, daily_meeting.schedule.to_s
  end

  def test_stringify_weekends_weekdays
    time = Time.new(2017, 3, 8, 0, 0, 0, "+00:00")
    weekend_meeting = create_meeting(recurrent: true,
      repeat_every: 1,
      schedule_rule: Meeting::Repeats::WEEKLY,
      repeats_on_week: ['0', '6'],
      start_time: time - 1.hour,
      end_time: time + 14.days,
      duration: 1.hour,
      repeats_end_date: time + 14.days
    )
    weekdays_meeting = create_meeting(recurrent: true,
      repeat_every: 1,
      schedule_rule: Meeting::Repeats::WEEKLY,
      repeats_on_week: ['1', '2', '3', '4', '5'],
      start_time: time - 1.hour,
      end_time: time + 14.days,
      duration: 1.hour,
      repeats_end_date: time + 14.days
    )
    assert_equal MeetingScheduleStringifier.new(weekend_meeting).stringify, weekend_meeting.schedule.to_s
    assert_equal MeetingScheduleStringifier.new(weekdays_meeting).stringify, weekdays_meeting.schedule.to_s
  end
end