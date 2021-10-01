module Program::Dashboard
  extend ActiveSupport::Concern

  included do
    include Program::Dashboard::ReportSubSectionSettings
    include Program::Dashboard::EnrollmentReport
    include Program::Dashboard::CommunityAnnouncementsEventsReport
    include Program::Dashboard::CommunityForumsArticlesReport
    include Program::Dashboard::CommunityResourcesReport
    include Program::Dashboard::EngagementsReport
    include Program::Dashboard::GroupsActivityReport
    include Program::Dashboard::MatchingReport
  end

  REPORT_TYPE_DATA_METHOD_MAPPING = {
    DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE => :get_invitation_acceptance_rate_data,
    DashboardReportSubSection::Type::Enrollment::APPLICATIONS_STATUS => :get_applications_status_data,
    DashboardReportSubSection::Type::Enrollment::PUBLISHED_PROFILES => :get_published_profiles_data,
    DashboardReportSubSection::Type::CommunityAnnouncementsEvents::ANNOUNCEMENTS_AND_EVENTS => :get_announcements_and_events_data,
    DashboardReportSubSection::Type::CommunityResources::RESOURCES => :get_resources_data
  }

  REPORT_TYPE_DATA_METHOD_MAPPING_WITH_DATE_RANGE = {
    DashboardReportSubSection::Type::CommunityForumsArticles::FORUMS_AND_ARTICLES => :get_forums_and_articles,
    DashboardReportSubSection::Type::Engagements::ENGAGEMENTS_HEALTH => :get_engagements_health_data,
    DashboardReportSubSection::Type::Engagements::ENGAGEMENTS_SURVEY_RESPONSES => :get_engagements_survey_responses_data,
    DashboardReportSubSection::Type::GroupsActivity::GROUPS_ACTIVITY => :get_groups_activity_data,
    DashboardReportSubSection::Type::GroupsActivity::MEETING_ACTIVITY => :get_meetings_activity_data
  }
  
  def current_status
    return {users: user_status(false), connections: connections_status, connected_users: connected_users_status}
  end

  def get_metrics(section)
    self.report_sections.find_by(default_section: section).metrics.without_perf_issues.includes(:section, :abstract_view, :alerts)
  end

  def get_data_for(report_type)
    self.send(REPORT_TYPE_DATA_METHOD_MAPPING[report_type])
  end

  def get_data_in_date_range_for(report_type, date_range)
    self.send(REPORT_TYPE_DATA_METHOD_MAPPING_WITH_DATE_RANGE[report_type], date_range)
  end

  def get_percentage_and_object_counts(date_range, objects)
    current_period_object_ids = objects.created_in_date_range(date_range).pluck(:id)
    prev_period_object_ids = get_prev_period_object_ids(date_range, objects)
    percentage, prev_period_objects_count = ReportsFilterService.set_percentage_from_ids(prev_period_object_ids, current_period_object_ids)
    prev_period_objects_count = 0 if prev_period_objects_count.blank?
    return percentage, prev_period_objects_count, current_period_object_ids.count
  end

  def get_prev_period_date_range(date_range)
    start_date = date_range.first.to_date
    end_date = date_range.last.to_date
    return ReportsFilterService.get_previous_time_period(start_date, end_date, self)
  end

  def get_attended_meeting_ids
    options = MeetingsFilterService.get_es_options_hash(self)
    @attended_meeting_ids ||= self.meetings.accepted_meetings.non_group_meetings.where(id: Meeting.get_meeting_ids_by_conditions(options)).pluck(:id)
  end

  private

  def get_prev_period_object_ids(date_range, objects)
    prev_period_start_date, prev_period_end_date = get_prev_period_date_range(date_range)
    return nil unless prev_period_start_date.present?
    prev_period_date_range = prev_period_start_date.beginning_of_day..prev_period_end_date.end_of_day
    objects.created_in_date_range(prev_period_date_range).pluck(:id)
  end

  def user_status(only_mentoring_roles=true)
    status = {}
    mentoring_roles = self.roles.for_mentoring
    role_ids = mentoring_roles.pluck(:id)
    status[:total] = only_mentoring_roles ? self.users.active.joins(:roles).where("roles.id IN (?)", role_ids).distinct.count : self.users.active.count
    mentoring_roles.each do |role|
      status[role.name] = self.send("#{role.name}_users").active.count
    end
    return status
  end

  def connections_status
    if self.only_one_time_mentoring_enabled?
      status = get_meeting_status
    else
      status = {ongoing: self.groups.active.count, closed: self.groups.closed.count}
      status.merge!({available: self.groups.pending.count}) if self.project_based?
      status[:total] = status.values.sum
    end
    return status
  end

  def connected_users_status
    self.only_one_time_mentoring_enabled? ? get_users_connected_via_meeting_status : get_users_connected_via_groups_status
  end

  def get_meeting_status
    meetings = Meeting.where(id: get_attended_meeting_ids)
    status = {total: meetings.with_endtime_in(MeetingsFilterService.get_start_time_end_time(ReportsFilterService.program_created_date(self), ReportsFilterService.dashboard_upcoming_end_date)).count}
    status[:upcoming] = meetings.with_endtime_in(MeetingsFilterService.get_start_time_end_time(ReportsFilterService.dashboard_upcoming_start_date, ReportsFilterService.dashboard_upcoming_end_date)).count
    status[:past] = meetings.with_endtime_in(MeetingsFilterService.get_start_time_end_time(ReportsFilterService.program_created_date(self), ReportsFilterService.dashboard_past_meetings_date)).count
    status[:completed] = meetings.with_endtime_in(MeetingsFilterService.get_start_time_end_time(ReportsFilterService.program_created_date(self), ReportsFilterService.dashboard_past_meetings_date)).where(state: Meeting::State::COMPLETED).count
    return status
  end

  def get_users_connected_via_meeting_status
    status = {}
    member_ids = MemberMeeting.where(meeting_id: get_attended_meeting_ids).pluck(:member_id).uniq
    status[:total] = self.users.active.where(member_id: member_ids).count
    self.roles.for_mentoring.each do |role|
      status[role.name] = self.send("#{role.name}_users").active.where(member_id: member_ids).count
    end
    return status
  end

  def get_users_connected_via_groups_status(scope=:active)
    status = {}
    group_ids = self.groups.send(scope).select(:id)
    active_user_ids = self.users.active.select(:id)
    conneted_user_ids = Connection::Membership.where(user_id: active_user_ids).where(group_id: group_ids).pluck(:user_id).uniq
    status[:total] = conneted_user_ids.size
    self.roles.for_mentoring.each do |role|
      role_user_ids = self.send("#{role.name}_users").active.pluck(:id)
      status[role.name] = (role_user_ids & conneted_user_ids).size
    end
    return status
  end

  def rounded_percentage(numerator, denominator, round_to=0)
    if denominator.zero?
      numerator.zero? ? 0 : 100 
    else
      (numerator.to_f*100/denominator).round(round_to)
    end
  end
end