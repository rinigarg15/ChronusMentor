module User::MeetingFeedbackWidget
  extend ActiveSupport::Concern
  FEEDBACK_WINDOW = 1.month
  MAX_SHOWN = 3

  def can_render_meeting_feedback_widget?
    program.calendar_enabled? && member_meetings_with_pending_meeting_feedback.any?
  end

  def member_meetings_with_pending_meeting_feedback
    meeting_ids = meeting_ids_eligible_for_meeting_feedback_widget
    member_meetings = member.member_meetings.where(meeting_id: meeting_ids).where.not(id: member_meeting_ids_with_feedback_provided).includes({:meeting => [:meeting_request]}, :member_meeting_responses)
    member_meetings.select{|mm| mm.get_response_object(mm.meeting.first_occurrence).accepted_or_not_responded?}.sort_by{|mm| mm.meeting.start_time}.first(MAX_SHOWN)
  end

  private

  def meeting_ids_eligible_for_meeting_feedback_widget
    self.member.meetings.of_program(self.program).non_group_meetings.accepted_meetings.between_time(Time.now - FEEDBACK_WINDOW, Time.now).pluck(:id)
  end

  def member_meeting_ids_with_feedback_provided
    self.survey_answers.where.not(member_meeting_id: nil).pluck(:member_meeting_id).uniq
  end
end