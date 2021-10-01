# == Schema Information
#
# Table name: report_view_columns
#
#  id          :integer          not null, primary key
#  program_id  :integer
#  report_type :string(255)
#  column_key  :text(65535)
#  position    :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#

class ReportViewColumn < ActiveRecord::Base
  include ApplicationHelper
  include GroupsReportHelper

  module ReportType
    GROUPS_REPORT = "groups_report"
    DEMOGRAPHIC_REPORT = "demographic_report"
  end

  module GroupsReport
    module Key
      GROUP = "group"
      MENTORS = "mentors"
      MENTEES = "mentees"
      STARTED_ON = "started_on"
      CLOSE_DATE = "close_date"
      MESSAGES_COUNT = "messages_count"
      POSTS_COUNT = "posts_count"
      MEETINGS_COUNT = "meetings_count"
      TASKS_COUNT = "tasks_count"
      SURVEY_RESPONSES_COUNT = "survey_responses_count"
      TOTAL_ACTIVITIES = "total_activities"
      CURRENT_STATUS = "current_status"
      MENTOR_MESSAGES_COUNT = "mentor_messages_count"
      MENTOR_POSTS_COUNT = "mentor_posts_count"
      MENTOR_MEETINGS_COUNT = "mentor_meetings_count"
      MENTOR_SURVEY_RESPONSES_COUNT = "mentor_survey_responses_count"
      MENTOR_TASKS_COUNT = "mentor_tasks_count"
      MENTEE_MESSAGES_COUNT = "mentee_messages_count"
      MENTEE_POSTS_COUNT = "mentee_posts_count"
      MENTEE_MEETINGS_COUNT = "mentee_meetings_count"
      MENTEE_TASKS_COUNT = "mentee_tasks_count"
      MENTEE_SURVEY_RESPONSES_COUNT = "mentee_survey_responses_count"
    end

    def self.translate(key, options = {})
      "feature.reports.groups_report_columns.#{key.to_s}".translate(options)
    end

    def self.all(options = {})
      {
        Key::GROUP => {:title => translate(Key::GROUP, {:Mentoring_Connection => options[:Mentoring_Connection]})},
        Key::MENTORS => {:title => translate(Key::MENTORS, {:Mentors => options[:Mentors]})},
        Key::MENTEES => {:title => translate(Key::MENTEES, {:Mentees => options[:Mentees]})},
        Key::STARTED_ON => {:title => translate(Key::STARTED_ON)},
        Key::CLOSE_DATE => {:title => translate(Key::CLOSE_DATE)},
        Key::SURVEY_RESPONSES_COUNT => {:title => translate(Key::SURVEY_RESPONSES_COUNT)},
        Key::MESSAGES_COUNT => {:title => translate(Key::MESSAGES_COUNT)},
        Key::POSTS_COUNT => { title: translate(Key::POSTS_COUNT) },
        Key::MEETINGS_COUNT => {:title => translate(Key::MEETINGS_COUNT, {:Meetings => options[:Meetings]})},
        Key::TASKS_COUNT => {:title => translate(Key::TASKS_COUNT)},
        Key::TOTAL_ACTIVITIES => {:title => translate(Key::TOTAL_ACTIVITIES)},
        Key::CURRENT_STATUS => {:title => translate(Key::CURRENT_STATUS)},
        Key::MENTOR_MESSAGES_COUNT => {:title => translate(Key::MENTOR_MESSAGES_COUNT, {:Mentor => options[:Mentor]})},
        Key::MENTOR_POSTS_COUNT => { title: translate(Key::MENTOR_POSTS_COUNT, Mentor: options[:Mentor]) },
        Key::MENTOR_MEETINGS_COUNT => {:title => translate(Key::MENTOR_MEETINGS_COUNT, {:Mentor => options[:Mentor], :Meetings => options[:Meetings]})},
        Key::MENTOR_TASKS_COUNT => {:title => translate(Key::MENTOR_TASKS_COUNT, {:Mentor => options[:Mentor]})},
        Key::MENTOR_SURVEY_RESPONSES_COUNT => {:title => translate(Key::MENTOR_SURVEY_RESPONSES_COUNT, {:Mentor => options[:Mentor]})},
        Key::MENTEE_MESSAGES_COUNT => {:title => translate(Key::MENTEE_MESSAGES_COUNT, {:Mentee => options[:Mentee]})},
        Key::MENTEE_POSTS_COUNT => { title: translate(Key::MENTEE_POSTS_COUNT, Mentee: options[:Mentee]) },
        Key::MENTEE_MEETINGS_COUNT => {:title => translate(Key::MENTEE_MEETINGS_COUNT, {:Mentee => options[:Mentee], :Meetings => options[:Meetings]})},
        Key::MENTEE_TASKS_COUNT => {:title => translate(Key::MENTEE_TASKS_COUNT, {:Mentee => options[:Mentee]})},
        Key::MENTEE_SURVEY_RESPONSES_COUNT => {:title => translate(Key::MENTEE_SURVEY_RESPONSES_COUNT, {:Mentee => options[:Mentee]})}
      }
    end

    def self.defaults
      [
        Key::GROUP, Key::MENTORS, Key::MENTEES, Key::STARTED_ON, Key::CLOSE_DATE,
        Key::MESSAGES_COUNT, Key::POSTS_COUNT, Key::MEETINGS_COUNT, Key::TASKS_COUNT, Key::SURVEY_RESPONSES_COUNT, Key::TOTAL_ACTIVITIES, Key::CURRENT_STATUS
      ]
    end

    def self.non_defaults
      self.all.keys - self.defaults
    end

    def self.message_columns
      [
        Key::MESSAGES_COUNT, Key::MENTOR_MESSAGES_COUNT, Key::MENTEE_MESSAGES_COUNT
      ]
    end

    def self.post_columns
      [
        Key::POSTS_COUNT, Key::MENTOR_POSTS_COUNT, Key::MENTEE_POSTS_COUNT
      ]
    end

    def self.mentoring_model_task_columns
      [
        Key::TASKS_COUNT, Key::MENTOR_TASKS_COUNT, Key::MENTEE_TASKS_COUNT
      ]
    end

    def self.meeting_columns
      [
        Key::MEETINGS_COUNT, Key::MENTOR_MEETINGS_COUNT, Key::MENTEE_MEETINGS_COUNT
      ]
    end

    def self.survey_responses_columns
      [
        Key::SURVEY_RESPONSES_COUNT, Key::MENTOR_SURVEY_RESPONSES_COUNT, Key::MENTEE_SURVEY_RESPONSES_COUNT
      ]
    end

    def self.activity_columns
      self.message_columns + self.post_columns + self.mentoring_model_task_columns + self.meeting_columns + self.survey_responses_columns + [Key::TOTAL_ACTIVITIES, Key::CURRENT_STATUS]
    end

    def self.mentor_columns
      [
        Key::MENTORS, Key::MENTOR_MESSAGES_COUNT, Key::MENTOR_POSTS_COUNT, Key::MENTOR_TASKS_COUNT, Key::MENTOR_MEETINGS_COUNT, Key::MENTOR_SURVEY_RESPONSES_COUNT
      ]
    end

    def self.mentee_columns
      [
        Key::MENTEES, Key::MENTEE_MESSAGES_COUNT, Key::MENTEE_POSTS_COUNT, Key::MENTEE_TASKS_COUNT, Key::MENTEE_MEETINGS_COUNT, Key::MENTEE_SURVEY_RESPONSES_COUNT
      ]
    end
  end

  module DemographicReport
    module Key
      COUNTRY = "country"
      ALL_USERS_COUNT = "all_users_count"
      MENTORS_COUNT = "mentors_count"
      MENTEES_COUNT = "mentees_count"
      EMPLOYEES_COUNT = "employees_count"

      DEFAULT_KEYS = [COUNTRY, ALL_USERS_COUNT]

      AGGREGATION = {
        Key::MENTORS_COUNT => :mentor_users_count,
        Key::MENTEES_COUNT => :student_users_count,
        Key::EMPLOYEES_COUNT => :employee_users_count,
        Key::ALL_USERS_COUNT => :all_users_count
      }
    end

    def self.translate(key, options = {})
      "feature.reports.demographic_report_columns.#{key.to_s}".translate(options)
    end

    def self.all(options = {})
      {
        Key::COUNTRY => {:title => translate(Key::COUNTRY)},
        Key::ALL_USERS_COUNT => {:title => translate(Key::ALL_USERS_COUNT)},
        Key::MENTORS_COUNT => {:title => translate(Key::MENTORS_COUNT, {:Mentors => options[:Mentors]})},
        Key::MENTEES_COUNT => {:title => translate(Key::MENTEES_COUNT, {:Mentees => options[:Mentees]})},
        Key::EMPLOYEES_COUNT => {:title => translate(Key::EMPLOYEES_COUNT, {:Employees => options[:Employees]})}
      }
    end

    #These columns have to be centered on display
    def self.columns_with_counts
      [
        Key::ALL_USERS_COUNT, Key::MENTORS_COUNT, Key::MENTEES_COUNT, Key::EMPLOYEES_COUNT
      ]
    end
  end

  belongs_to_program

  validates :program_id, :presence => true
  validates :report_type, :presence => true, :inclusion => {:in => [ReportType::GROUPS_REPORT, ReportType::DEMOGRAPHIC_REPORT]}
  validates :column_key,
    :presence => true,
    :uniqueness => {:scope => [:program_id, :report_type]},
    :inclusion => {:in => GroupsReport.all.keys + DemographicReport.all.keys}

  scope :for_demographic_report, -> { where(:report_type => ReportType::DEMOGRAPHIC_REPORT)}
  scope :for_groups_report, -> { where(:report_type => ReportType::GROUPS_REPORT)}

  # Instance Methods
  def get_title(report, options = {})
    case report
    when ReportType::GROUPS_REPORT then GroupsReport.all(options)[self.column_key][:title]
    when ReportType::DEMOGRAPHIC_REPORT then DemographicReport.all(options)[self.column_key][:title]
    end
  end

  def is_sortable?
    !GroupsReport.meeting_columns.include?(self.column_key) && self.column_key != ReportViewColumn::GroupsReport::Key::TOTAL_ACTIVITIES
  end

  # Class Methods
  # The conditions here are supposed to be similar to groups_listing list view.
  def self.get_applicable_groups_report_columns(program, column_keys = ReportViewColumn::GroupsReport.all.keys)
    column_keys -= ReportViewColumn::GroupsReport.mentoring_model_task_columns unless program.mentoring_connections_v2_enabled?
    column_keys -= ReportViewColumn::GroupsReport.meeting_columns unless program.mentoring_connection_meeting_enabled?
    column_keys -= ReportViewColumn::GroupsReport.message_columns unless program.group_messaging_enabled?
    column_keys -= ReportViewColumn::GroupsReport.post_columns unless program.group_forum_enabled?
    column_keys -= ReportViewColumn::GroupsReport.survey_responses_columns unless program.mentoring_connections_v2_enabled? && program.surveys.of_engagement_type.present?
    column_keys
  end

  def self.get_default_groups_report_columns(program)
    self.get_applicable_groups_report_columns(program, ReportViewColumn::GroupsReport.defaults)
  end

  # Insance Methods
  # Groups Report
  # The conditions here are supposed to be similar to groups_listing list view.
  def get_groups_report_column_data_for_table_row_or_csv(groups_report, group)
    case self.column_key
    when ReportViewColumn::GroupsReport::Key::GROUP
      group.name
    when ReportViewColumn::GroupsReport::Key::MENTORS
      group.mentors.collect(&:name).to_sentence
    when ReportViewColumn::GroupsReport::Key::MENTEES
      group.students.collect(&:name).to_sentence
    when ReportViewColumn::GroupsReport::Key::STARTED_ON
      started_on = formatted_time_in_words(group.published_at, :no_ago => true, :no_time => true)
    when ReportViewColumn::GroupsReport::Key::CLOSE_DATE
      close_date = group.closed_at.present? ? group.closed_at : group.expiry_time
      formatted_time_in_words(close_date, :no_ago => true, :no_time => true)
    when ReportViewColumn::GroupsReport::Key::CURRENT_STATUS
      get_groups_status_string(group.status)
    when ReportViewColumn::GroupsReport::Key::TOTAL_ACTIVITIES
      groups_report.messages_by_group[group.id].to_i + groups_report.posts_by_group[group.id].to_i + groups_report.tasks_by_group[group.id].to_i + groups_report.meetings_by_group[group.id].to_i + groups_report.survey_responses_by_group[group.id].to_i

    # Messages
    when ReportViewColumn::GroupsReport::Key::MESSAGES_COUNT
      get_scraps_by_group(group, groups_report.messages_by_group[group.id])
    when ReportViewColumn::GroupsReport::Key::MENTOR_MESSAGES_COUNT
      get_scraps_by_group(group, groups_report.mentor_messages_by_group[group.id])
    when ReportViewColumn::GroupsReport::Key::MENTEE_MESSAGES_COUNT
      get_scraps_by_group(group, groups_report.mentee_messages_by_group[group.id])

    # Posts
    when ReportViewColumn::GroupsReport::Key::POSTS_COUNT
      get_posts_by_group(group, groups_report.posts_by_group[group.id])
    when ReportViewColumn::GroupsReport::Key::MENTOR_POSTS_COUNT
      get_posts_by_group(group, groups_report.mentor_posts_by_group[group.id])
    when ReportViewColumn::GroupsReport::Key::MENTEE_POSTS_COUNT
      get_posts_by_group(group, groups_report.mentee_posts_by_group[group.id])

    # Tasks
    when ReportViewColumn::GroupsReport::Key::TASKS_COUNT
      groups_report.tasks_by_group[group.id].to_i
    when ReportViewColumn::GroupsReport::Key::MENTOR_TASKS_COUNT
      groups_report.mentor_tasks_by_group[group.id].to_i
    when ReportViewColumn::GroupsReport::Key::MENTEE_TASKS_COUNT
      groups_report.mentee_tasks_by_group[group.id].to_i

    # Meetings
    when ReportViewColumn::GroupsReport::Key::MEETINGS_COUNT
      get_meetings_by_group(group, groups_report.meetings_by_group[group.id])
    when ReportViewColumn::GroupsReport::Key::MENTOR_MEETINGS_COUNT
      get_meetings_by_group(group, groups_report.mentor_meetings_by_group[group.id])
    when ReportViewColumn::GroupsReport::Key::MENTEE_MEETINGS_COUNT
      get_meetings_by_group(group, groups_report.mentee_meetings_by_group[group.id])

    # Survey Responses
    when ReportViewColumn::GroupsReport::Key::SURVEY_RESPONSES_COUNT
      get_survey_responses_by_group(group, groups_report.survey_responses_by_group[group.id])
    when ReportViewColumn::GroupsReport::Key::MENTOR_SURVEY_RESPONSES_COUNT
      get_survey_responses_by_group(group, groups_report.mentor_survey_responses_by_group[group.id])
    when ReportViewColumn::GroupsReport::Key::MENTEE_SURVEY_RESPONSES_COUNT
      get_survey_responses_by_group(group, groups_report.mentee_survey_responses_by_group[group.id])
    end
  end

  def get_posts_by_group(group, posts_by_group)
    group.forum_enabled? ? posts_by_group.to_i : "-"
  end

  def get_meetings_by_group(group, meetings_by_group)
    group.meetings_enabled? ? meetings_by_group.to_i : "-"
  end

  def get_survey_responses_by_group(group, survey_responses_by_group)
    admin_role = group.program.roles.with_name(RoleConstants::ADMIN_NAME)
    group.can_manage_mm_engagement_surveys?(admin_role) ? survey_responses_by_group.to_i : "-"
  end

  def get_scraps_by_group(group, scraps_by_group)
    group.scraps_enabled? ? scraps_by_group.to_i : "-"
  end
end
