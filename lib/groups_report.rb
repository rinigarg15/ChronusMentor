class GroupsReport

  attr_accessor :program, :mentor_role_id, :mentee_role_id, :group_ids,
    :start_time, :end_time, :date_range,
    :columns, :message_columns, :post_columns, :task_columns, :meeting_columns, :survey_responses_columns, :other_columns, :totals,
    :messages_by_period, :posts_by_period, :tasks_by_period, :meetings_by_period, :survey_responses_by_period,
    :messages_by_group, :posts_by_group, :tasks_by_group, :meetings_by_group,
    :mentor_messages_by_group, :mentor_posts_by_group, :mentor_tasks_by_group, :survey_responses_by_group, :mentor_meetings_by_group, :mentor_survey_responses_by_group, :mentee_messages_by_group, :mentee_posts_by_group, :mentee_tasks_by_group, :mentee_meetings_by_group, :mentee_survey_responses_by_group, :point_interval, :categories, :activity_groups, :no_activity_groups

  def initialize(program, columns = [], options = {})
    self.program = program
    self.mentor_role_id = program.roles.find_by(name: RoleConstants::MENTOR_NAME).id
    self.mentee_role_id = program.roles.find_by(name: RoleConstants::STUDENT_NAME).id
    self.group_ids = options[:group_ids].presence || []
    self.point_interval = options[:point_interval]

    self.start_time = options[:start_time]
    self.end_time = options[:end_time]
    self.date_range = options[:start_time]..options[:end_time]

    # 'Columns' refer to column-keys
    self.columns = columns
    self.message_columns = columns & ReportViewColumn::GroupsReport.message_columns
    self.post_columns = columns & ReportViewColumn::GroupsReport.post_columns
    self.task_columns = columns & ReportViewColumn::GroupsReport.mentoring_model_task_columns
    self.meeting_columns = columns & ReportViewColumn::GroupsReport.meeting_columns
    self.survey_responses_columns = columns & ReportViewColumn::GroupsReport.survey_responses_columns
    self.other_columns = columns - (self.message_columns + self.post_columns + self.task_columns + self.meeting_columns  + self.survey_responses_columns)
  end

  module PointInterval
    DAY = 1
    WEEK = 7
    MONTH = 30
  end

  module ColumnName
    POSTS = "posts"
    MESSAGES = "messages"
    TASKS = "tasks"
    SURVEY_RESPONSES = "survey_responses"
  end

  module Roles
    MENTOR = "mentor"
    STUDENT = "student"
  end

  #### Table - Messages/Posts/Tasks/Meetings/Survey Responses Totals - depends on columns selected ####
  #### Called directly for pagination and columns update - ajax actions ####
  def compute_table_totals(management_report=false)
    initialize_table_totals!
    compute_messages_or_posts_totals!(self.message_columns, ColumnName::MESSAGES)
    compute_messages_or_posts_totals!(self.post_columns, ColumnName::POSTS)
    compute_tasks_or_survey_response_totals!(self.task_columns, ColumnName::TASKS)
    compute_tasks_or_survey_response_totals!(self.survey_responses_columns, ColumnName::SURVEY_RESPONSES)
    compute_meeting_totals!
    compute_other_column_totals!
    compute_data_for_table_row_or_csv unless management_report
  end

  #### Chart - Messages/Posts/Tasks/Meetings/Survey Responses by period ####
  #### Table - Messages/Posts/Tasks/Meetings/Survey Responses Totals - depends on columns selected ####
  #### Called on page load ###
  def compute_data_for_view
    initialize_data_for_view!
    compute_table_totals
    compute_groups_report_activity_stats
    compute_messages_data_for_view! if program_has_messages_enabled?
    compute_posts_data_for_view! if program_has_posts_enabled?
    compute_tasks_data_for_view! if program_has_tasks_enabled?
    compute_meetings_data_for_view! if program_has_meetings_enabled?
    compute_survey_responses_for_view! if program_has_surveys_enabled? 
  end

  #### Messages/Posts/Tasks/Meetings/Survey Responses by group - depends on columns selected ####
  #### For CSV rendering ####
  def compute_data_for_table_row_or_csv
    initialize_data_for_csv!
    compute_messages_or_posts_for_csv!(self.message_columns, ColumnName::MESSAGES)
    compute_messages_or_posts_for_csv!(self.post_columns, ColumnName::POSTS)
    compute_tasks_data_for_csv!
    compute_meetings_data_for_csv!
    compute_survey_responses_for_csv!
  end

  def compute_groups_report_activity_stats
    total_groups = self.group_ids.size
    return if total_groups == 0
    groups_with_activity = get_groups_with_activity
    initialize_groups_report_activity_stats(groups_with_activity, total_groups)
  end

  private

  def initialize_table_totals!
    self.totals = {}
    self.columns.each { |column| self.totals[column] = 0 }
    initialize_group_activity_totals
  end

  def initialize_group_activity_totals
    self.totals[ReportViewColumn::GroupsReport::Key::MESSAGES_COUNT] = 0
    self.totals[ReportViewColumn::GroupsReport::Key::POSTS_COUNT] = 0 
    self.totals[ReportViewColumn::GroupsReport::Key::TASKS_COUNT] = 0 
    self.totals[ReportViewColumn::GroupsReport::Key::MEETINGS_COUNT] = 0 
    self.totals[ReportViewColumn::GroupsReport::Key::SURVEY_RESPONSES_COUNT] = 0
    self.totals[ReportViewColumn::GroupsReport::Key::TOTAL_ACTIVITIES] = 0 
  end

  def initialize_data_for_view!
    initialize_table_totals!

    # Highcharts requires an array sorted on dates
    self.messages_by_period = ActiveSupport::OrderedHash.new
    self.posts_by_period = ActiveSupport::OrderedHash.new
    self.tasks_by_period = ActiveSupport::OrderedHash.new
    self.meetings_by_period = ActiveSupport::OrderedHash.new
    self.survey_responses_by_period = ActiveSupport::OrderedHash.new

    chart_period = get_chart_period
      
    chart_period.each do |period|
      self.messages_by_period[period] = 0
      self.posts_by_period[period] = 0
      self.tasks_by_period[period] = 0
      self.meetings_by_period[period] = 0
      self.survey_responses_by_period[period] = 0
    end
  end

  def initialize_data_for_csv!
    self.messages_by_group = {}
    self.mentor_messages_by_group = {}
    self.mentee_messages_by_group = {}

    self.posts_by_group = {}
    self.mentor_posts_by_group = {}
    self.mentee_posts_by_group = {}

    self.tasks_by_group = {}
    self.mentor_tasks_by_group = {}
    self.mentee_tasks_by_group = {}

    self.meetings_by_group = {}
    self.mentor_meetings_by_group = {}
    self.mentee_meetings_by_group = {}

    self.survey_responses_by_group = {}
    self.mentor_survey_responses_by_group = {}
    self.mentee_survey_responses_by_group = {}
  end

  def fetch_messages
    @messages = self.program.scraps.where(ref_obj_id: self.group_ids, ref_obj_type: Group.name).created_in_date_range(self.date_range)
  end

  def fetch_posts
    group_forum_ids = self.program.forums.where(group_id: self.group_ids).pluck(:id)
    @posts = self.program.posts.joins(:topic).where(topics: { forum_id: group_forum_ids } ).created_in_date_range(self.date_range)
  end

  def fetch_tasks
    @tasks = self.program.mentoring_model_tasks.status(MentoringModel::Task::Status::DONE).where(group_id: self.group_ids).completed_in_date_range(self.date_range)
  end

  def fetch_meetings
    group_meetings = self.program.meetings.where(group_id: self.group_ids).select("id, group_id, schedule, start_time, recurrent").
      slot_availability_meetings.between_time(self.start_time, self.end_time).includes(member_meetings: [:member_meeting_responses])
    meetings = Meeting.recurrent_meetings(group_meetings, get_merged_list: true, with_in_time: true, start_time: self.start_time, end_time: self.end_time)
    @meetings = Meeting.has_attendance_more_than(meetings, 1)
  end

  def fetch_survey_responses
    @survey_responses = SurveyAnswer.where(group_id: self.group_ids).last_answered_in_date_range(self.date_range).select(["common_answers.id, common_answers.response_id, common_answers.group_id, common_answers.last_answered_at, common_answers.user_id"]).includes(:answer_choices).group("common_answers.response_id, common_answers.user_id")
  end

  #### Groups Report View ####
  #### Chart Data - Messages/Tasks/Meetings/Survey Responses by period ####
  def compute_messages_data_for_view!
    messages = @messages || fetch_messages
    self.messages_by_period.merge!(Hash[messages.group_by { |message| get_group_by_period(message.created_at) }.map { |k, v| [k, v.length] } ])
  end

  def compute_posts_data_for_view!
    posts = @posts || fetch_posts
    self.posts_by_period.merge!(Hash[posts.group_by { |post| get_group_by_period(post.created_at) }.map { |k, v| [k, v.length] } ])
  end

  def compute_tasks_data_for_view!
    tasks = @tasks || fetch_tasks
    self.tasks_by_period.merge!(Hash[tasks.group_by { |task| get_group_by_period(task.completed_date) }.map { |k, v| [k, v.length] } ])
  end

  def compute_meetings_data_for_view!
    meeting_occurrences = @meetings || fetch_meetings
    meeting_occurrences.each do |meeting|
      period = get_group_by_period(meeting[:current_occurrence_time])
      self.meetings_by_period[period] += 1
    end
  end

  def compute_survey_responses_for_view!
    survey_responses = @survey_responses || fetch_survey_responses
    self.survey_responses_by_period.merge!(Hash[survey_responses.group_by { |survey_response| get_group_by_period(survey_response.last_answered_at) }.map { |k, v| [k, v.length] } ])
  end

  def get_chart_period
    point_interval = self.point_interval
    start_date = self.start_time.to_date
    end_date = self.end_time.to_date

    if point_interval == PointInterval::WEEK
      return (start_date..end_date).map{ |date| get_monday_of_the_week(date) }.uniq
    elsif point_interval == PointInterval::DAY
      return (start_date..end_date)
    else
      return (start_date..end_date).map{ |date| date.strftime('%Y%m') }.uniq
    end
  end

  def get_group_by_period(date)
    point_interval = self.point_interval
    if point_interval == PointInterval::WEEK
      return get_monday_of_the_week(date)
    elsif point_interval == PointInterval::DAY
      return date.to_date
    else
      return date.strftime('%Y%m')
    end
  end

  def get_monday_of_the_week(date_time)
    date = date_time.to_date
    date - ((date.wday - 1) % 7)
  end

  #### Chart Data - END ####

  #### Total Activity Pie Chart - Messages/Tasks/Posts/Meetings/Survey Responses ####

  def initialize_groups_report_activity_stats(groups_with_activity, total_groups)
    self.activity_groups = groups_with_activity
    self.no_activity_groups = total_groups - groups_with_activity
  end

  def get_groups_with_activity
    group_ids = []
    group_ids += fetch_tasks.pluck(:group_id)
    group_ids += fetch_posts.joins(topic: :forum).pluck("forums.group_id")
    group_ids += fetch_survey_responses.pluck(:group_id)
    group_ids += fetch_messages.pluck(:ref_obj_id)
    group_ids += compute_group_ids_with_meetings
    group_ids.uniq.count
  end

  def compute_group_ids_with_meetings
    meeting_group_ids = []
    meeting_occurrences = fetch_meetings
    meeting_occurrences.each do |meeting|
      meeting_group_ids += [meeting[:meeting].group_id]
    end
    meeting_group_ids
  end

  #### Total Activity Pie Chart - END ####

  #### Table totals ####
  def compute_messages_or_posts_totals!(columns, column_name="")
    return unless messages_or_posts_enabled?(column_name)
    table_columns = columns + (column_name == ColumnName::MESSAGES ? [ReportViewColumn::GroupsReport::Key::MESSAGES_COUNT] : [ReportViewColumn::GroupsReport::Key::POSTS_COUNT])
    table_columns = table_columns.uniq
    mentee_role_id_count_map_list, mentor_role_id_count_map_list = compute_role_id_count_map_lists(columns, column_name)
    table_columns.each do |column|
      self.totals[column] = 
      case column
        when ReportViewColumn::GroupsReport::Key::MESSAGES_COUNT
          (@messages || fetch_messages).size
        when ReportViewColumn::GroupsReport::Key::POSTS_COUNT
          fetch_posts.size
        when ReportViewColumn::GroupsReport::Key::MENTOR_MESSAGES_COUNT
          mentor_role_id_count_map_list
        when ReportViewColumn::GroupsReport::Key::MENTOR_POSTS_COUNT
          mentor_role_id_count_map_list
        when ReportViewColumn::GroupsReport::Key::MENTEE_MESSAGES_COUNT
          mentee_role_id_count_map_list
        when ReportViewColumn::GroupsReport::Key::MENTEE_POSTS_COUNT
          mentee_role_id_count_map_list
      end
    end
  end

  def messages_or_posts_enabled?(column_name)
    (program_has_messages_enabled? && column_name == ColumnName::MESSAGES) || (program_has_posts_enabled? && column_name == ColumnName::POSTS)
  end

  def get_role_id_count_map_list(columns, column_name)
    role_ids = get_role_ids(columns)
    return nil unless role_ids.present?
    column_name == ColumnName::MESSAGES ? Group.get_rolewise_scraps_activity(self.group_ids, role_ids, self.date_range) : Group.get_rolewise_posts_activity(self.group_ids, role_ids, self.date_range)
  end

  def compute_role_id_count_map_lists(columns, column_name)
    role_id_count_map_list = get_role_id_count_map_list(columns, column_name)
    return if role_id_count_map_list.blank?
    role_id_count_map_list = role_id_count_map_list.values

    mentee_role_id_count_map_list = role_id_count_map_list.sum { |role_id_count_map| role_id_count_map[self.mentee_role_id] } if (columns.include?(ReportViewColumn::GroupsReport::Key::MENTEE_MESSAGES_COUNT) || columns.include?(ReportViewColumn::GroupsReport::Key::MENTEE_POSTS_COUNT))
    mentor_role_id_count_map_list = role_id_count_map_list.sum { |role_id_count_map| role_id_count_map[self.mentor_role_id] } if (columns.include?(ReportViewColumn::GroupsReport::Key::MENTOR_MESSAGES_COUNT) || columns.include?(ReportViewColumn::GroupsReport::Key::MENTOR_POSTS_COUNT))
    return mentee_role_id_count_map_list, mentor_role_id_count_map_list
  end

  def compute_tasks_or_survey_response_totals!(columns, column_name)
    return unless tasks_or_survey_responses_enabled?(column_name)
    table_columns = columns + (column_name == ColumnName::TASKS ? [ReportViewColumn::GroupsReport::Key::TASKS_COUNT] : [ReportViewColumn::GroupsReport::Key::SURVEY_RESPONSES_COUNT])
    tasks_or_survey_responses = get_tasks_or_survey_responses(column_name)
    table_columns = table_columns.uniq
    table_columns.each do |column|
      self.totals[column] =
        case column
        when ReportViewColumn::GroupsReport::Key::TASKS_COUNT
          tasks_or_survey_responses.size
        when ReportViewColumn::GroupsReport::Key::MENTOR_TASKS_COUNT
          role_based_task_totals!(tasks_or_survey_responses, Roles::MENTOR)
        when ReportViewColumn::GroupsReport::Key::MENTEE_TASKS_COUNT
          role_based_task_totals!(tasks_or_survey_responses, Roles::STUDENT)
        when ReportViewColumn::GroupsReport::Key::SURVEY_RESPONSES_COUNT
          tasks_or_survey_responses.length
        when ReportViewColumn::GroupsReport::Key::MENTOR_SURVEY_RESPONSES_COUNT
          role_based_survey_responses_totals!(tasks_or_survey_responses, Roles::MENTOR)
        when ReportViewColumn::GroupsReport::Key::MENTEE_SURVEY_RESPONSES_COUNT
          role_based_survey_responses_totals!(tasks_or_survey_responses, Roles::STUDENT)
        end
    end
  end

  def get_tasks_or_survey_responses(column_name)
    column_name == ColumnName::TASKS ? fetch_tasks : fetch_survey_responses
  end

  def tasks_or_survey_responses_enabled?(column_name)
    (program_has_tasks_enabled? && column_name == ColumnName::TASKS) || (program_has_surveys_enabled? && column_name == ColumnName::SURVEY_RESPONSES)
  end

  def role_based_task_totals!(tasks, membership_role)
    tasks_with_roles = membership_role == Roles::MENTOR ? tasks.joins(group: :mentor_memberships) : tasks.joins(group: :student_memberships)
    tasks_with_roles.where("connection_membership_id = connection_memberships.id").size
  end

  def role_based_survey_responses_totals!(survey_responsess, membership_role)
    survey_responsess_with_roles = membership_role == Roles::MENTOR ? survey_responsess.joins(group: :mentor_memberships) : survey_responsess.joins(group: :student_memberships)
    survey_responsess_with_roles.where("common_answers.user_id = connection_memberships.user_id").length
  end

  def compute_meeting_totals!
    return unless program_has_meetings_enabled?
    meeting_occurrences = @meetings || fetch_meetings
    mentor_meetings_count = self.meeting_columns.include?(ReportViewColumn::GroupsReport::Key::MENTOR_MEETINGS_COUNT)
    mentee_meetings_count = self.meeting_columns.include?(ReportViewColumn::GroupsReport::Key::MENTEE_MEETINGS_COUNT)
    meeting_occurrences.each do |meeting_occurrence|
      meeting = meeting_occurrence[:meeting]
      occurrence_time = meeting_occurrence[:current_occurrence_time]
      group = meeting.group
      self.totals[ReportViewColumn::GroupsReport::Key::MEETINGS_COUNT] += 1
      if mentor_meetings_count
        if meeting.any_attending?(occurrence_time, group.mentors.pluck(:member_id))
          self.totals[ReportViewColumn::GroupsReport::Key::MENTOR_MEETINGS_COUNT] += 1
        end
      end
      if mentee_meetings_count
        if meeting.any_attending?(occurrence_time, group.students.pluck(:member_id))
          self.totals[ReportViewColumn::GroupsReport::Key::MENTEE_MEETINGS_COUNT] += 1
        end
      end
    end
  end

  def compute_other_column_totals!
    other_columns = self.other_columns + [ReportViewColumn::GroupsReport::Key::TOTAL_ACTIVITIES]
    other_columns.each do |column|
      self.totals[column] =
        if column == ReportViewColumn::GroupsReport::Key::GROUP
          self.group_ids.size
        elsif column == ReportViewColumn::GroupsReport::Key::MENTORS
          Connection::MentorMembership.where(group_id: self.group_ids).size
        elsif column == ReportViewColumn::GroupsReport::Key::MENTEES
          Connection::MenteeMembership.where(group_id: self.group_ids).size
        elsif column == ReportViewColumn::GroupsReport::Key::TOTAL_ACTIVITIES
          get_totals_for_total_activities
        end
    end
  end

  def get_totals_for_total_activities
    self.totals[ReportViewColumn::GroupsReport::Key::SURVEY_RESPONSES_COUNT] + self.totals[ReportViewColumn::GroupsReport::Key::MEETINGS_COUNT] + self.totals[ReportViewColumn::GroupsReport::Key::MESSAGES_COUNT] + self.totals[ReportViewColumn::GroupsReport::Key::POSTS_COUNT] + self.totals[ReportViewColumn::GroupsReport::Key::TASKS_COUNT]
  end
  #### Table totals - END ####
  #### Groups Report View - END ####

  #### Groups Report CSV - Messages/Posts/Tasks/Meetings/Survey Responses by group ####
  def compute_messages_or_posts_for_csv!(columns, column_name="")
    group_id_role_id_count_map = get_role_id_count_map_list(columns, column_name)
    columns = columns + [ReportViewColumn::GroupsReport::Key::MESSAGES_COUNT] + [ReportViewColumn::GroupsReport::Key::POSTS_COUNT]
    columns = columns.uniq
    columns.each do |column| 
      case column
        when ReportViewColumn::GroupsReport::Key::MESSAGES_COUNT
          self.messages_by_group = get_messages_by_group
        when ReportViewColumn::GroupsReport::Key::POSTS_COUNT
          self.posts_by_group = get_posts_by_group
        when ReportViewColumn::GroupsReport::Key::MENTOR_MESSAGES_COUNT
          get_mentor_role_wise_count_map(group_id_role_id_count_map, column_name)
        when ReportViewColumn::GroupsReport::Key::MENTOR_POSTS_COUNT
          get_mentor_role_wise_count_map(group_id_role_id_count_map, column_name)
        when ReportViewColumn::GroupsReport::Key::MENTEE_MESSAGES_COUNT
          get_mentee_role_wise_count_map(group_id_role_id_count_map, column_name)
        when ReportViewColumn::GroupsReport::Key::MENTEE_POSTS_COUNT
          get_mentee_role_wise_count_map(group_id_role_id_count_map, column_name)
      end
    end
  end

  def get_mentor_role_wise_count_map(group_id_role_id_count_map, column_name)
    mentor_role_id = self.mentor_role_id
    group_id_role_id_count_map.each do |group_id, role_id_count_map|
      self.mentor_messages_by_group[group_id] = role_id_count_map[mentor_role_id] if column_name == ColumnName::MESSAGES
      self.mentor_posts_by_group[group_id] = role_id_count_map[mentor_role_id] if column_name == ColumnName::POSTS
    end
  end

  def get_mentee_role_wise_count_map(group_id_role_id_count_map, column_name)
    mentee_role_id = self.mentee_role_id
    group_id_role_id_count_map.each do |group_id, role_id_count_map|
      self.mentee_messages_by_group[group_id] = role_id_count_map[mentee_role_id] if column_name == ColumnName::MESSAGES
      self.mentee_posts_by_group[group_id] = role_id_count_map[mentee_role_id] if column_name == ColumnName::POSTS
    end
  end

  def compute_tasks_data_for_csv!
    tasks = @tasks || fetch_tasks
    columns = self.task_columns + [ReportViewColumn::GroupsReport::Key::TASKS_COUNT]
    columns = columns.uniq
    columns.each do |column|
      if column == ReportViewColumn::GroupsReport::Key::TASKS_COUNT
        self.tasks_by_group = get_tasks_by_group
      elsif column == ReportViewColumn::GroupsReport::Key::MENTOR_TASKS_COUNT
        self.mentor_tasks_by_group = get_role_based_tasks_for_csv!(tasks, Roles::MENTOR)
      elsif column == ReportViewColumn::GroupsReport::Key::MENTEE_TASKS_COUNT
        self.mentee_tasks_by_group = get_role_based_tasks_for_csv!(tasks, Roles::STUDENT)
      end
    end
  end

  def get_role_based_tasks_for_csv!(tasks, membership_role)
    tasks_with_memberships = (membership_role == Roles::MENTOR ? tasks.joins(group: :mentor_memberships) : tasks.joins(group: :student_memberships))
    tasks_with_memberships.where("connection_membership_id = connection_memberships.id").group("mentoring_model_tasks.group_id").count
  end

  def compute_survey_responses_for_csv!
    survey_responses =  @survey_responses || fetch_survey_responses
    columns = self.survey_responses_columns + [ReportViewColumn::GroupsReport::Key::SURVEY_RESPONSES_COUNT]
    columns = columns.uniq
    columns.each do |column|
      case column
      when ReportViewColumn::GroupsReport::Key::SURVEY_RESPONSES_COUNT
        self.survey_responses_by_group = get_survey_responses_by_group
      when ReportViewColumn::GroupsReport::Key::MENTOR_SURVEY_RESPONSES_COUNT
        self.mentor_survey_responses_by_group = get_role_based_survey_responses_for_csv!(survey_responses, Roles::MENTOR)
      when ReportViewColumn::GroupsReport::Key::MENTEE_SURVEY_RESPONSES_COUNT
        self.mentee_survey_responses_by_group = get_role_based_survey_responses_for_csv!(survey_responses, Roles::STUDENT)
      end
    end
  end

  def get_role_based_survey_responses_for_csv!(survey_responses, membership_role)
    survey_responses_with_memberships = (membership_role == Roles::MENTOR ? survey_responses.joins(group: :mentor_memberships) : survey_responses.joins(group: :student_memberships))
    Hash[survey_responses_with_memberships.where("common_answers.user_id = connection_memberships.user_id").group_by(&:group_id).map { |k, v| [k, v.length] }]
  end

  def compute_meetings_data_for_csv!
    meeting_occurrences = @meetings || fetch_meetings
    mentor_meetings_count = self.meeting_columns.include?(ReportViewColumn::GroupsReport::Key::MENTOR_MEETINGS_COUNT)
    mentee_meetings_count = self.meeting_columns.include?(ReportViewColumn::GroupsReport::Key::MENTEE_MEETINGS_COUNT)
    meeting_occurrences.each do |meeting_occurrence|
      meeting = meeting_occurrence[:meeting]
      occurrence_time = meeting_occurrence[:current_occurrence_time]
      group = meeting.group
      self.meetings_by_group[group.id] = self.meetings_by_group[group.id].present? ? (self.meetings_by_group[group.id] + 1) : 1
      if mentor_meetings_count
        if meeting.any_attending?(occurrence_time, group.mentors.pluck(:member_id))
          self.mentor_meetings_by_group[group.id] = self.mentor_meetings_by_group[group.id].present? ? (self.mentor_meetings_by_group[group.id] + 1) : 1
        end
      end
      if mentee_meetings_count
        if meeting.any_attending?(occurrence_time, group.students.pluck(:member_id))
          self.mentee_meetings_by_group[group.id] = self.mentee_meetings_by_group[group.id].present? ? (self.mentee_meetings_by_group[group.id] + 1) : 1
        end
      end
    end
  end

  def get_tasks_by_group
    tasks = @tasks || fetch_tasks
    tasks.group("mentoring_model_tasks.group_id").count
  end

  def get_posts_by_group
    posts = @posts || fetch_posts
    posts.joins(topic: :forum).group("forums.group_id").count
  end

  def get_messages_by_group
    messages = @messages || fetch_messages
    messages.group(:ref_obj_id).count
  end

  def get_survey_responses_by_group
    survey_responses = @survey_responses || fetch_survey_responses
    Hash[survey_responses.group_by(&:group_id).map { |k, v| [k, v.length] }]
  end
  #### Groups Report CSV - END ####

  def get_role_ids(columns)
    role_ids = []
    role_ids << self.mentor_role_id if (columns & ReportViewColumn::GroupsReport.mentor_columns).any?
    role_ids << self.mentee_role_id if (columns & ReportViewColumn::GroupsReport.mentee_columns).any?
    role_ids
  end

  def program_has_tasks_enabled?
    self.program.mentoring_connections_v2_enabled?
  end

  def program_has_meetings_enabled?
    self.program.mentoring_connection_meeting_enabled?
  end

  def program_has_messages_enabled?
    self.program.group_messaging_enabled?
  end

  def program_has_posts_enabled?
    self.program.group_forum_enabled?
  end

  def program_has_surveys_enabled?
    self.program.mentoring_connections_v2_enabled? && self.program.surveys.of_engagement_type.present?
  end
end