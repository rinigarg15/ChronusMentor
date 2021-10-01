class MentoringSessionsFilterService

  def initialize(program, filters)
    @program = program
    @filters = filters
  end

  def get_filtered_meetings
    options = MeetingsFilterService.get_es_options_hash(@program)

    options.merge!({"attendees.id": get_attendee_id}) if get_attendee_id.present?
    meeting_ids = Meeting.get_meeting_ids_by_conditions(options)
    meetings = get_meetings(meeting_ids)

    return meetings
  end

  def get_meetings(meeting_ids)
    Meeting.accepted_meetings.group_meetings.where(id: meeting_ids).includes({:members => :users})
  end

  def get_attendee_id
    return nil unless @filters[:mentoring_session].present? && @filters[:mentoring_session][:attendee].present?
    attendee = GetMemberFromNameWithEmailService.new(@filters[:mentoring_session][:attendee], @program.organization).member
    return attendee.present? ? attendee.id : 0
  end

  def get_number_of_filters
    count = @filters[:mentoring_session].present? && @filters[:mentoring_session][:attendee].present? ? 1 : 0
    return count
  end
end