module Program::Dashboard::MatchingReport
  extend ActiveSupport::Concern

  def get_matching_reports_to_display
    DashboardReportSubSection::Type::Matching.all.select{|report_type| self.is_report_enabled?(report_type)}
  end

  private

  def get_connected_ongoing_users_data
    sub_setting = get_sub_setting(DashboardReportSubSection::Type::Matching::CONNECTED_USERS)
    connected_users = get_users_connected_via_groups_status(get_groups_scope_for_sub_setting(sub_setting))
    users = user_status
    get_connected_users_data(users, connected_users)
  end

  def get_connected_flash_users_data
    connected_users = get_users_connected_via_meeting_status
    users = user_status
    get_connected_users_data(users, connected_users)
  end

  def get_connected_users_data(users, connected_users)
    data = {total: rounded_percentage(connected_users[:total], users[:total])}
    self.roles.for_mentoring.each do |role|
      data[role.name] = rounded_percentage(connected_users[role.name], users[role.name])
    end
    return data
  end

  def get_groups_scope_for_sub_setting(sub_setting)
    case sub_setting
    when DashboardReportSubSection::Type::Matching::ConnectedUsers::ONLY_ONGOING
      :active
    when DashboardReportSubSection::Type::Matching::ConnectedUsers::ONGOING_AND_CLOSED
      :active_or_closed
    when DashboardReportSubSection::Type::Matching::ConnectedUsers::ONGOING_AND_DRAFTED
      :active_or_drafted
    end
  end

  def get_mentor_requests_data
    {sent: self.mentor_requests.count, accepted: self.mentor_requests.accepted.count, rejected: self.mentor_requests.with_status_in([MentorRequest::Status::REJECTED, MentorRequest::Status::WITHDRAWN, MentorRequest::Status::CLOSED]).count, report_type: DashboardReportSubSection::Type::Matching::MENTOR_REQUESTS}
  end

  def get_project_requests_data
    {sent: self.project_requests.count, accepted: self.project_requests.accepted.count, rejected: self.project_requests.with_status_in([MentorRequest::Status::REJECTED, MentorRequest::Status::WITHDRAWN, MentorRequest::Status::CLOSED]).count, report_type: DashboardReportSubSection::Type::Matching::PROJECT_REQUESTS}
  end

  def get_meeting_requests_data
    {sent: self.meeting_requests.count, accepted: self.meeting_requests.accepted.count, rejected: self.meeting_requests.with_status_in([MentorRequest::Status::REJECTED, MentorRequest::Status::WITHDRAWN, MentorRequest::Status::CLOSED]).count, report_type: DashboardReportSubSection::Type::Matching::MEETING_REQUESTS}
  end
end