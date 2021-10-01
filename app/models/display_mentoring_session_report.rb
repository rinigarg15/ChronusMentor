class DisplayMentoringSessionReport
  attr_accessor :report_obj, :start_time, :duration, :is_meeting, :location, :members

  def initialize(mentoring_session_obj)
    date = mentoring_session_obj.start_time
    self.is_meeting = mentoring_session_obj.is_a?(Meeting)
    self.report_obj = mentoring_session_obj
    self.location = mentoring_session_obj.location
    self.duration = mentoring_session_obj.duration_in_hours
    start_time_from_beginning = mentoring_session_obj.start_time - mentoring_session_obj.start_time.beginning_of_day
    self.start_time = (mentoring_session_obj.computed_start_time.beginning_of_day + start_time_from_beginning)
    self.members = [mentoring_session_obj.member]
  end
end