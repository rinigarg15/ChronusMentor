module Program::Dashboard::GroupsActivityReport
  extend ActiveSupport::Concern

  def get_groups_activity_report_to_display
    report = self.only_one_time_mentoring_enabled? ? DashboardReportSubSection::Type::GroupsActivity::MEETING_ACTIVITY : DashboardReportSubSection::Type::GroupsActivity::GROUPS_ACTIVITY
    return report if self.is_report_enabled?(report)
  end

  module Activities
    MESSAGES_ACTIVITY = :messages_activity
    TASKS_ACTIVITY = :tasks_activity
    MEETINGS_ACTIVITY = :meetings_activity
    SURVEYS_ACTIVITY = :surveys_activity
    POSTS_ACTIVITY = :posts_activity

    def self.all
      [POSTS_ACTIVITY, MESSAGES_ACTIVITY, MEETINGS_ACTIVITY, TASKS_ACTIVITY, SURVEYS_ACTIVITY]
    end
  end

  module MeetingActivities
    ACCEPTED = :accepted
    SCHEDULED = :scheduled
    UNSCHEDULED = :unscheduled

    PENDING = :pending
    COMPLETED = :completed
    CANCELLED = :cancelled

    MESSAGES = :messages
    MENTOR_SURVEY = :mentor_survey
    MENTEE_SURVEY = :mentee_survey
  end

  def get_groups_activity_data(date_range)
    @groups_report = initialize_groups_report(date_range)
    return {} if @groups_report.nil?
    groups_activity_summary(date_range)
    initialize_prev_period_activity_hash
    get_previous_period_groups_activity_summary(date_range)
    compute_group_activity_percentage_change_hash
    {current_period_activity_hash: @current_period_activity_hash, previous_period_activity_hash: @previous_period_activity_hash, percentage_hash: @percentage_hash}.merge!(groups_activity)
  end

  def groups_activity
    @groups_report.compute_groups_report_activity_stats
    {groups_with_activity: @groups_report.activity_groups, groups_with_no_activity: @groups_report.no_activity_groups, groups_report: @groups_report}
  end

  def get_meetings_activity_data(date_range)
    {accepted_data: get_meetings_accepted_data(date_range), completed_data: get_meetings_completed_data(date_range), activity: get_meetings_message_survey_data(date_range)}
  end

  private

  def get_meetings_accepted_data(date_range)
    compute_current_previous_and_percent(:compute_meetings_accepted_data, [:accepted, :scheduled, :unscheduled], date_range)
  end

  def compute_meetings_accepted_data(date_range)
    start_date, end_date = [date_range.begin, date_range.end]
    accepted_meeting_request_ids = MeetingRequest.accepted_in(MeetingsFilterService.get_start_time_end_time(start_date, end_date)).pluck(:id)
    meetings = Meeting.where(id: get_attended_meeting_ids).where(meeting_request_id: accepted_meeting_request_ids)
    scheduled = meetings.slot_availability_meetings.count
    unscheduled = meetings.general_availability_meetings.count
    {accepted: scheduled+unscheduled, scheduled: scheduled, unscheduled: unscheduled}
  end

  def get_meetings_completed_data(date_range)
    compute_current_previous_and_percent(:compute_meetings_completed_data, [:pending, :completed, :cancelled], date_range)
  end

  def compute_meetings_completed_data(date_range)
    start_date, end_date = [date_range.begin, date_range.end]
    meetings = Meeting.where(id: get_attended_meeting_ids).with_endtime_in(MeetingsFilterService.get_start_time_end_time(start_date, end_date))
    pending = meetings.where(state: nil).count
    completed = meetings.completed.count
    cancelled = meetings.cancelled.count
    {pending: pending, completed: completed, cancelled: cancelled}
  end

  def get_meetings_message_survey_data(date_range)
    compute_current_previous_and_percent(:compute_meetings_message_survey_data, [:messages, :mentor_survey, :mentee_survey], date_range)
  end

  def compute_meetings_message_survey_data(date_range)
    meeting_ids = get_attended_meeting_ids
    member_meeting_ids = MemberMeeting.where(meeting_id: meeting_ids).pluck(:id)
    scraps = Scrap.where(ref_obj_type: Meeting.name, ref_obj_id: meeting_ids).created_in_date_range(date_range).count
    mentor_survey_responses = compute_meetings_survey_data_for_role(date_range, member_meeting_ids, RoleConstants::MENTOR_NAME)
    mentee_survey_responses = compute_meetings_survey_data_for_role(date_range, member_meeting_ids, RoleConstants::STUDENT_NAME)
    {messages: scraps, mentor_survey: mentor_survey_responses, mentee_survey: mentee_survey_responses}
  end

  def compute_meetings_survey_data_for_role(date_range, member_meeting_ids, role_name)
    survey = self.get_meeting_feedback_survey_for_role(role_name)
    survey.survey_answers.where(member_meeting_id: member_meeting_ids).last_answered_in_date_range(date_range).group(:response_id).pluck(:response_id).size
  end

  def compute_current_previous_and_percent(method_sym, keys, date_range)
    prev_period_start_date, prev_period_end_date = get_prev_period_date_range(date_range)
    previous_period_activity_hash = prev_period_start_date.present? ? send(method_sym, prev_period_start_date..prev_period_end_date) : {pending: nil, completed: nil, cancelled: nil}
    current_period_activity_hash = send(method_sym, date_range)
    percentage_hash = compute_percentage_change_hash(keys, current_period_activity_hash, previous_period_activity_hash)
    {current_period_activity_hash: current_period_activity_hash, previous_period_activity_hash: previous_period_activity_hash, percentage_hash: percentage_hash}
  end

  def groups_activity_summary(date_range)
    @groups_report ||= initialize_groups_report(date_range)
    @groups_report.compute_table_totals(true)
    @current_period_activity_hash = compute_current_period_activity_hash
  end

  def get_previous_period_groups_activity_summary(date_range)
    prev_period_start_date, prev_period_end_date = get_prev_period_date_range(date_range)
    return @previous_period_activity_hash unless prev_period_start_date.present?

    prev_period_date_range = prev_period_start_date..prev_period_end_date
    @previous_period_groups_report = initialize_groups_report(prev_period_date_range)
    @previous_period_activity_hash = compute_previous_period_activity_hash unless @previous_period_groups_report.nil?
    @previous_period_activity_hash
  end

  def compute_current_period_activity_hash
    {groups: @group_ids.count, total_activity: @groups_report.totals[ReportViewColumn::GroupsReport::Key::TOTAL_ACTIVITIES], posts_activity: @groups_report.totals[ReportViewColumn::GroupsReport::Key::POSTS_COUNT], messages_activity: @groups_report.totals[ReportViewColumn::GroupsReport::Key::MESSAGES_COUNT], tasks_activity: @groups_report.totals[ReportViewColumn::GroupsReport::Key::TASKS_COUNT], meetings_activity: @groups_report.totals[ReportViewColumn::GroupsReport::Key::MEETINGS_COUNT], surveys_activity: @groups_report.totals[ReportViewColumn::GroupsReport::Key::SURVEY_RESPONSES_COUNT]}
  end

  def compute_previous_period_activity_hash
    @previous_period_groups_report.compute_table_totals(true)
    {messages_activity: @previous_period_groups_report.totals[ReportViewColumn::GroupsReport::Key::MESSAGES_COUNT], tasks_activity: @previous_period_groups_report.totals[ReportViewColumn::GroupsReport::Key::TASKS_COUNT], meetings_activity: @previous_period_groups_report.totals[ReportViewColumn::GroupsReport::Key::MEETINGS_COUNT], surveys_activity: @previous_period_groups_report.totals[ReportViewColumn::GroupsReport::Key::SURVEY_RESPONSES_COUNT], posts_activity: @previous_period_groups_report.totals[ReportViewColumn::GroupsReport::Key::POSTS_COUNT]}
  end

  def initialize_prev_period_activity_hash
    @previous_period_activity_hash = {messages_activity: nil, tasks_activity: nil, meetings_activity: nil, surveys_activity: nil, posts_activity: nil }
  end

  def compute_group_activity_percentage_change_hash
    @percentage_hash = {}
    Activities.all.each do |activity|
      @percentage_hash[activity] = ReportsFilterService.get_percentage_change(@previous_period_activity_hash[activity], @current_period_activity_hash[activity])
      @previous_period_activity_hash[activity] = 0 if @previous_period_activity_hash[activity].blank?
    end
  end

  def compute_percentage_change_hash(hash_keys, current_period_activity_hash, previous_period_activity_hash)
    percentage_hash = {}
    hash_keys.each do |activity|
      percentage_hash[activity] = ReportsFilterService.get_percentage_change(previous_period_activity_hash[activity], current_period_activity_hash[activity])
    end
    return percentage_hash
  end

  def initialize_groups_report(date_range)
    groups_report_columns = [ReportViewColumn::GroupsReport::Key::MESSAGES_COUNT, ReportViewColumn::GroupsReport::Key::POSTS_COUNT, ReportViewColumn::GroupsReport::Key::MEETINGS_COUNT, ReportViewColumn::GroupsReport::Key::TASKS_COUNT, ReportViewColumn::GroupsReport::Key::SURVEY_RESPONSES_COUNT, ReportViewColumn::GroupsReport::Key::TOTAL_ACTIVITIES]
    start_date = date_range.first.beginning_of_day
    end_date = date_range.last.end_of_day
    @group_ids = self.published_groups_in_date_range(start_date, end_date).pluck(:id)
    ::GroupsReport.new(self, groups_report_columns, {group_ids: @group_ids, start_time: start_date, end_time: end_date}) unless @group_ids.blank?
  end
end