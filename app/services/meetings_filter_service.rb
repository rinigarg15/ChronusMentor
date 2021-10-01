class MeetingsFilterService

  attr_accessor :program, :filters

  def self.get_es_options_hash(program)
    {not_cancelled: true, program_id: program.id, active: true}
  end

  def initialize(program, filters)
    @program = program
    @filters = filters
  end

  def get_filtered_meeting_ids
    options = MeetingsFilterService.get_es_options_hash(program)

    options.merge!({"attendees.id": get_attendee_id}) if get_attendee_id.present?
    meeting_ids = Meeting.get_meeting_ids_by_conditions(options) 
    start_date, end_date = ReportsFilterService.get_report_date_range(filters, MeetingsController::CalendarSessionConstants::DEFAULT_LIMIT.ago)
    
    duration = (end_date - start_date).to_i + 1
    prev_period_start_date = start_date - duration.days

    if prev_period_start_date >= @program.created_at.to_date
      prev_period_end_date = start_date - 1.days
      prev_period_meeting_ids = get_meeting_ids(prev_period_start_date, prev_period_end_date, meeting_ids)
      prev_period_meeting_ids = apply_user_profile_filter(prev_period_meeting_ids)
      prev_period_meeting_ids_after_survey_filter = apply_survey_filter(prev_period_meeting_ids)
    end

    meeting_ids = get_meeting_ids(start_date, end_date, meeting_ids)
    meeting_ids = apply_user_profile_filter(meeting_ids)
    meeting_ids_after_survey_filter = apply_survey_filter(meeting_ids)

    return meeting_ids_after_survey_filter, prev_period_meeting_ids_after_survey_filter
  end

  def get_meeting_ids(start_date, end_date, meeting_ids)
    Meeting.accepted_meetings.non_group_meetings.with_endtime_in(MeetingsFilterService.get_start_time_end_time(start_date, end_date)).where(id: meeting_ids).pluck(:id)
  end

  def get_attendee_id
    return nil unless filters[:meeting_session].present? && filters[:meeting_session][:attendee].present?
    attendee = GetMemberFromNameWithEmailService.new(filters[:meeting_session][:attendee], program.organization).member
    return attendee.present? ? attendee.id : 0
  end

  def apply_survey_filter(meeting_ids)
    return meeting_ids unless filters[:meeting_session].present? && filters[:meeting_session][:survey].present? && filters[:meeting_session][:survey_status].present?
    survey = program.surveys.of_meeting_feedback_type.find(filters[:meeting_session][:survey])
    case filters[:meeting_session][:survey_status].to_i
    when Survey::Status::COMPLETED
      survey.get_answered_meeting_ids & meeting_ids
    when Survey::Status::OVERDUE
      Meeting.past.where(id: meeting_ids).pluck(:id) - survey.get_answered_meeting_ids
    else
      return meeting_ids
    end
  end

  def apply_user_profile_filter(meeting_ids)
    return meeting_ids unless filters[:report].present? && filters[:report][:profile_questions].present?

    @profile_filter_params = Survey::Report.remove_incomplete_report_filters(filters[:report][:profile_questions])
    return meeting_ids if @profile_filter_params.blank?
    dynamic_profile_filter_params = ReportsFilterService.dynamic_profile_filter_params(@profile_filter_params)

    member_ids = program.member_meetings.where(:meeting_id => meeting_ids).pluck("DISTINCT member_id")
    member_ids = UserAndMemberFilterService.apply_profile_filtering(member_ids, dynamic_profile_filter_params, {:for_report_filter => true})

    meeting_ids_after_profile_filter = program.member_meetings.where(:member_id => member_ids).pluck("DISTINCT meeting_id")

    return (meeting_ids_after_profile_filter & meeting_ids)
  end

  def get_number_of_filters
    count = 0
    return count unless filters[:meeting_session].present?
    count += 1 if filters[:meeting_session][:survey].present? && filters[:meeting_session][:survey_status].present?
    count += 1 if filters[:meeting_session][:attendee].present?
    count += 1 if @profile_filter_params.present?
    return count
  end

  def self.get_start_time_end_time(start_date, end_date)
    [start_date.in_time_zone(Time.zone).beginning_of_day, end_date.in_time_zone(Time.zone).end_of_day]
  end
end