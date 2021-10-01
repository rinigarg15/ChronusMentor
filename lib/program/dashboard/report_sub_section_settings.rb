module Program::Dashboard::ReportSubSectionSettings
  extend ActiveSupport::Concern

  module Setting
    DEFAULT_STATE = {
      DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE => true,
      DashboardReportSubSection::Type::Enrollment::APPLICATIONS_STATUS => true,
      DashboardReportSubSection::Type::Enrollment::PUBLISHED_PROFILES => true,
      DashboardReportSubSection::Type::CommunityAnnouncementsEvents::ANNOUNCEMENTS_AND_EVENTS => true,
      DashboardReportSubSection::Type::CommunityResources::RESOURCES => true, 
      DashboardReportSubSection::Type::CommunityForumsArticles::FORUMS_AND_ARTICLES => true,
      DashboardReportSubSection::Type::Engagements::ENGAGEMENTS_HEALTH => true,
      DashboardReportSubSection::Type::Engagements::ENGAGEMENTS_SURVEY_RESPONSES => true,
      DashboardReportSubSection::Type::GroupsActivity::GROUPS_ACTIVITY => true,
      DashboardReportSubSection::Type::GroupsActivity::MEETING_ACTIVITY => true,
      DashboardReportSubSection::Type::Matching::CONNECTED_USERS => true,
      DashboardReportSubSection::Type::Matching::CONNECTED_FLASH_USERS => true,
      DashboardReportSubSection::Type::Matching::MENTOR_REQUESTS => true,
      DashboardReportSubSection::Type::Matching::PROJECT_REQUESTS => true,
      DashboardReportSubSection::Type::Matching::MEETING_REQUESTS => true
    }

    AVAILABILITY_CONDITION = {
      DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE => Proc.new{|program| program.invitable_roles_by_admins.any?},
      DashboardReportSubSection::Type::Enrollment::APPLICATIONS_STATUS => Proc.new{|program| program.allow_join_now?},
      DashboardReportSubSection::Type::CommunityResources::RESOURCES => Proc.new{|program| program.resources_enabled?},
      DashboardReportSubSection::Type::CommunityForumsArticles::FORUMS_AND_ARTICLES => Proc.new{|program| program.forums_enabled? || program.articles_enabled?},
      DashboardReportSubSection::Type::Engagements::ENGAGEMENTS_HEALTH => Proc.new{|program| program.ongoing_mentoring_enabled? || program.only_one_time_mentoring_enabled?},
      DashboardReportSubSection::Type::Engagements::ENGAGEMENTS_SURVEY_RESPONSES => Proc.new{|program| program.ongoing_mentoring_enabled? || program.only_one_time_mentoring_enabled?},
      DashboardReportSubSection::Type::GroupsActivity::GROUPS_ACTIVITY => Proc.new{|program| program.ongoing_mentoring_enabled?},
      DashboardReportSubSection::Type::GroupsActivity::MEETING_ACTIVITY => Proc.new{|program| program.only_one_time_mentoring_enabled?},
      DashboardReportSubSection::Type::Matching::CONNECTED_USERS => Proc.new{|program| !program.only_one_time_mentoring_enabled?},
      DashboardReportSubSection::Type::Matching::MENTOR_REQUESTS => Proc.new{|program| MentorRequestView.is_accessible?(program)},
      DashboardReportSubSection::Type::Matching::PROJECT_REQUESTS => Proc.new{|program| program.project_based?},
      DashboardReportSubSection::Type::Matching::MEETING_REQUESTS => Proc.new{|program| program.only_one_time_mentoring_enabled?},
      DashboardReportSubSection::Type::Matching::CONNECTED_FLASH_USERS => Proc.new{|program| program.only_one_time_mentoring_enabled?}
    }
  end

  module SubSetting
    DEFAULT_SUB_SETTING = {
      # passing program as a param as we might plan to change the default option based on the type of program
      DashboardReportSubSection::Type::Matching::CONNECTED_USERS => Proc.new{|_program| DashboardReportSubSection::Type::Matching::ConnectedUsers::ONLY_ONGOING }
    }
  end

  def is_report_enabled?(report_type)
    is_report_available?(report_type) && (has_dashboard_report_object?(report_type) ? dashboard_report_object(report_type).enabled : Setting::DEFAULT_STATE[report_type])
  end

  def is_report_available?(report_type)
    !Setting::AVAILABILITY_CONDITION[report_type].present? || Setting::AVAILABILITY_CONDITION[report_type].call(self)
  end

  def enable_dashboard_report!(report_type, enabled=true, setting=nil)
    dashboard_report = dashboard_report_object(report_type) || self.dashboard_reports.new(report_type: report_type)
    dashboard_report.enabled = enabled
    dashboard_report.setting = setting
    dashboard_report.save!
  end

  def get_reports_available_for_section(section)
    DashboardReportSubSection::Tile::REPORTS_MAPPING[section].select{|report_type| self.is_report_available?(report_type)}
  end

  def get_sub_setting(report_type)
    has_dashboard_report_object?(report_type) ? dashboard_report_object(report_type).setting : SubSetting::DEFAULT_SUB_SETTING[report_type].call(self)
  end

  private

  def has_dashboard_report_object?(report_type)
    dashboard_report_object(report_type).present?    
  end

  def dashboard_report_object(report_type)
    dashboard_report_objects.find{|report| report.report_type == report_type}
  end

  def dashboard_report_objects
    @dashboard_report_objects ||= dashboard_reports
  end
end