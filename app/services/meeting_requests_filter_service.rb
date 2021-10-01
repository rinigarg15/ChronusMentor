class MeetingRequestsFilterService

  def initialize(program, filters)
    @program = program
    @filters = filters
  end

  def get_filtered_meeting_request_ids
    start_date, end_date = ReportsFilterService.get_report_date_range(@filters,  @program.created_at)
    
    duration = (end_date - start_date).to_i + 1
    prev_period_start_date = start_date - duration.days

    if prev_period_start_date >= @program.created_at.to_date
      prev_period_end_date = start_date - 1.days
      prev_period_meeting_request_ids = get_meeting_request_ids(prev_period_start_date, prev_period_end_date)
    end

    meeting_request_ids = get_meeting_request_ids(start_date, end_date)
    return meeting_request_ids, prev_period_meeting_request_ids
  end

  def get_meeting_request_ids(start_date, end_date)
    start_time = start_date.beginning_of_day.to_datetime
    end_time = end_date.end_of_day.to_datetime
    return @program.meeting_requests.where(created_at: ((start_time)..(end_time))).pluck(:id)
  end
end