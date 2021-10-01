module GroupsReportExtensions
  include GroupsReportHelper

  CSV_PROCESSES = 4
  CSV_SLICE_SIZE = 1000

  def sort_by_groups_report_column(groups, sort_param, sort_order, start_time, end_time)
    case sort_param
    when ReportViewColumn::GroupsReport::Key::GROUP
      sort_by_group_name(groups, sort_order)
    when ReportViewColumn::GroupsReport::Key::STARTED_ON
      sort_by_started_on(groups, sort_order)
    when ReportViewColumn::GroupsReport::Key::CLOSE_DATE
      sort_by_close_date(groups, sort_order)
    when ReportViewColumn::GroupsReport::Key::CURRENT_STATUS
      sort_by_current_status(groups, sort_order)
    when ReportViewColumn::GroupsReport::Key::MENTORS
      role_sort_by_name(groups, :mentors, sort_order)
    when ReportViewColumn::GroupsReport::Key::MENTEES
      role_sort_by_name(groups, :students, sort_order)
    when ReportViewColumn::GroupsReport::Key::MESSAGES_COUNT
      sort_by_messages_count(groups, sort_order, start_time, end_time)
    when ReportViewColumn::GroupsReport::Key::POSTS_COUNT
      sort_by_posts_count(groups, sort_order, start_time, end_time)
    when ReportViewColumn::GroupsReport::Key::TASKS_COUNT
      sort_by_tasks_count(groups, sort_order, start_time, end_time)
    when ReportViewColumn::GroupsReport::Key::SURVEY_RESPONSES_COUNT
      sort_by_survey_responses_count(groups, sort_order, start_time, end_time)
    when ReportViewColumn::GroupsReport::Key::MENTOR_MESSAGES_COUNT
      role_sort_by_messages_count(groups, :mentors, sort_order, start_time, end_time)
    when ReportViewColumn::GroupsReport::Key::MENTOR_POSTS_COUNT
      role_sort_by_posts_count(groups, :mentor_memberships, sort_order, start_time, end_time)
    when ReportViewColumn::GroupsReport::Key::MENTOR_TASKS_COUNT
      role_sort_by_tasks_count(groups, :mentor_memberships, sort_order, start_time, end_time)
    when ReportViewColumn::GroupsReport::Key::MENTOR_SURVEY_RESPONSES_COUNT
      role_sort_by_survey_responses_count(groups, :mentor_memberships, sort_order, start_time, end_time)
    when ReportViewColumn::GroupsReport::Key::MENTEE_MESSAGES_COUNT
      role_sort_by_messages_count(groups, :students, sort_order, start_time, end_time)
    when ReportViewColumn::GroupsReport::Key::MENTEE_POSTS_COUNT
      role_sort_by_posts_count(groups, :student_memberships, sort_order, start_time, end_time)
    when ReportViewColumn::GroupsReport::Key::MENTEE_TASKS_COUNT
      role_sort_by_tasks_count(groups, :student_memberships, sort_order, start_time, end_time)
    when ReportViewColumn::GroupsReport::Key::MENTEE_SURVEY_RESPONSES_COUNT
      role_sort_by_survey_responses_count(groups, :student_memberships, sort_order, start_time, end_time)
    else
      groups
    end
  end

  def update_groups_report_view!(program, column_keys_param)
    existing_columns = program.report_view_columns.for_groups_report.dup
    (column_keys_param & ReportViewColumn::GroupsReport.all.keys).each_with_index do |column_key, index|
      column = existing_columns.find { |column| column.column_key == column_key }
      if column.present?
        column.update_attributes!(position: index)
        existing_columns -= [column]
      else
        program.report_view_columns.create!(
          column_key: column_key,
          report_type: ReportViewColumn::ReportType::GROUPS_REPORT,
          position: index
        )
      end
    end
    existing_columns.collect(&:destroy)
  end

  def export_groups_report_to_stream(stream, groups_report, groups, report_view_columns, custom_term_options)
    column_titles = []
    batch_size = [1 + groups.to_a.count / CSV_PROCESSES, CSV_SLICE_SIZE].min
    report_view_columns.each do |column|
      column_titles << column.get_title(ReportViewColumn::ReportType::GROUPS_REPORT, custom_term_options)
    end
    stream << CSV::Row.new(column_titles, column_titles).to_s
    groups.find_in_batches(batch_size: batch_size) do |groups_batch|
      Parallel.each(groups_batch, in_processes: CSV_PROCESSES) do |group|
        @reconnected ||= ActiveRecord::Base.connection.reconnect!
        group_data = []
        report_view_columns.each do |column|
          group_data << column.get_groups_report_column_data_for_table_row_or_csv(groups_report, group)
        end
        stream << CSV::Row.new(column_titles, group_data).to_s
      end
    end
  end

  def get_groups_report_eager_loadables(column_keys)
    eager_loadables = []
    if (column_keys & ReportViewColumn::GroupsReport.mentor_columns).any?
      eager_loadables << { mentors: [:roles, :member] }
    end
    if (column_keys & ReportViewColumn::GroupsReport.mentee_columns).any?
      eager_loadables << { students: [:roles, :member] }
    end
    if (column_keys & ReportViewColumn::GroupsReport.meeting_columns).any?
      eager_loadables << { program: [:disabled_db_features, :enabled_db_features, organization: :enabled_db_features] }
    end
    eager_loadables
  end

  private

  def common_select_attributes
    "groups.id, groups.name, groups.program_id, groups.expiry_time, groups.closed_at, groups.published_at, groups.status, groups.mentoring_model_id"
  end

  def sort_by_group_name(groups, sort_order)
    groups.select(common_select_attributes).
      order("groups.name #{sort_order}")
  end

  def sort_by_started_on(groups, sort_order)
    groups.select(common_select_attributes).
      order("groups.published_at #{sort_order}")
  end

  def sort_by_current_status(groups, sort_order)
    sorted_status_array = get_groups_status_sorted(sort_order)
    groups.select(common_select_attributes).order("FIELD(groups.status, #{sorted_status_array.join ', '})")
  end

  def sort_by_close_date(groups, sort_order)

    # Active connections are sorted based on 'expiry_time' and Closed are based on 'closed_at' .
    # 'closed_at' is null for active connections. And 'closed_at' <= 'expiry_time' for closed connections.
    # When groups are sorted on both columns(First closed_at.Then expiry_time) in ascending order,
    # Null values comes first (MySql Default for Asc). This makes expiry time to be on top. Not desired.
    # ISNULL(<field>) pushes the NULL values to end. Vice versa for Descending order.
    order_criteria = (sort_order == "asc")? "ISNULL(groups.closed_at)" : "! ISNULL(groups.closed_at)";

    groups.select(common_select_attributes).
      order(order_criteria + ", groups.closed_at #{sort_order}, groups.expiry_time #{sort_order}")
  end

  def role_sort_by_name(groups, role, sort_order)
    groups.select(common_select_attributes).
      joins(role => :member).
      group("groups.id").
      order("CONCAT(members.first_name, members.last_name) #{sort_order}")
  end

  def sort_by_messages_count(groups, sort_order, start_time, end_time)
    groups.select(common_select_attributes + ", COUNT(messages.id) as messages_count").
      joins("LEFT OUTER JOIN messages ON
        messages.type IN ('#{Scrap.name}') AND
        messages.ref_obj_id = groups.id AND
        messages.ref_obj_type = '#{Group.name}' AND
        messages.created_at BETWEEN '#{start_time}' AND '#{end_time}'").
      group("groups.id").
      order("messages_count #{sort_order}")
  end

  def sort_by_posts_count(groups, sort_order, start_time, end_time)
    groups.select(common_select_attributes + ", COUNT(posts.id) as posts_count").
      joins("LEFT OUTER JOIN forums ON forums.group_id = groups.id").
      joins("LEFT OUTER JOIN topics ON topics.forum_id = forums.id").
      joins("LEFT OUTER JOIN posts ON
        posts.topic_id = topics.id AND
        posts.created_at BETWEEN '#{start_time}' AND '#{end_time}'").
      group("groups.id").
      order("posts_count #{sort_order}")
  end

  def sort_by_tasks_count(groups, sort_order, start_time, end_time)
    groups.select(common_select_attributes + ", COUNT(mentoring_model_tasks.id) as tasks_count").
      joins("LEFT OUTER JOIN mentoring_model_tasks ON
        mentoring_model_tasks.group_id = groups.id AND
        mentoring_model_tasks.status = #{MentoringModel::Task::Status::DONE} AND
        mentoring_model_tasks.completed_date BETWEEN '#{start_time}' AND '#{end_time}'").
      group("groups.id").
      order("tasks_count #{sort_order}")
  end

  def sort_by_survey_responses_count(groups, sort_order, start_time, end_time)
    groups.select(common_select_attributes + ", COUNT(DISTINCT common_answers.response_id, common_answers.user_id) as survey_responses_count").
      joins("LEFT OUTER JOIN common_answers ON
        common_answers.group_id = groups.id AND
        common_answers.last_answered_at BETWEEN '#{start_time}' AND '#{end_time}' AND common_answers.is_draft IS false").
      group("groups.id").
      order("survey_responses_count #{sort_order}")
  end

  def role_sort_by_messages_count(groups, role, sort_order, start_time, end_time)
    groups.select(common_select_attributes + ", COUNT(messages.id) as messages_count").
      joins(role => :member).
      joins("LEFT OUTER JOIN messages ON
        messages.sender_id = members.id AND
        messages.type IN ('#{Scrap.name}') AND
        messages.ref_obj_id = groups.id AND
        messages.ref_obj_type = '#{Group.name}' AND
        messages.created_at BETWEEN '#{start_time}' AND '#{end_time}'").
      group("groups.id").
      order("messages_count #{sort_order}")
  end

  def role_sort_by_posts_count(groups, role, sort_order, start_time, end_time)
    groups.select(common_select_attributes + ", COUNT(posts.id) as posts_count").
      joins(role).
      joins("LEFT OUTER JOIN forums ON forums.group_id = groups.id").
      joins("LEFT OUTER JOIN topics ON topics.forum_id = forums.id").
      joins("LEFT OUTER JOIN posts ON
        posts.user_id = connection_memberships.user_id AND
        posts.topic_id = topics.id AND
        posts.created_at BETWEEN '#{start_time}' AND '#{end_time}'").
      group("groups.id").
      order("posts_count #{sort_order}")
  end

  def role_sort_by_tasks_count(groups, role, sort_order, start_time, end_time)
    groups.select(common_select_attributes + ", COUNT(mentoring_model_tasks.id) as mentor_tasks_count").
      joins(role).
      joins("LEFT OUTER JOIN mentoring_model_tasks ON
        mentoring_model_tasks.connection_membership_id = connection_memberships.id AND
        mentoring_model_tasks.status = #{MentoringModel::Task::Status::DONE} AND
        mentoring_model_tasks.completed_date BETWEEN '#{start_time}' AND '#{end_time}'").
      group("groups.id").
      order("mentor_tasks_count #{sort_order}")
  end

  def role_sort_by_survey_responses_count(groups, role_membership, sort_order, start_time, end_time)
    groups.select(common_select_attributes + ", COUNT(DISTINCT common_answers.response_id, common_answers.user_id) as survey_responses_count").
      joins(role_membership).
      joins("LEFT OUTER JOIN common_answers ON
        common_answers.group_id = groups.id AND
        common_answers.user_id = connection_memberships.user_id AND
        common_answers.last_answered_at BETWEEN '#{start_time}' AND '#{end_time}' AND common_answers.is_draft IS false").
      group("groups.id").
      order("survey_responses_count #{sort_order}")
  end
end