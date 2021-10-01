include IceCube
class UpdateMeetingTimeForGaMeetings< ActiveRecord::Migration[4.2]
  def change
    Meeting.general_availability_meetings.includes([:member_meetings, :survey_answers]).find_each do |meeting|
      start_time = meeting.start_time.round_to_next
      end_time = meeting.end_time.round_to_next
      duration = end_time - start_time
      schedule = Schedule.new(start_time, :duration => duration)
      schedule.add_recurrence_rule meeting.build_rule.until(start_time)
      meeting.update_columns(start_time: start_time, end_time: end_time, schedule: schedule) #skips validations & callbacks
      meeting.survey_answers.update_all(meeting_occurrence_time: start_time)
    end
  end
end