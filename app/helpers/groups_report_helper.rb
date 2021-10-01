module GroupsReportHelper

  MESSAGES_COLOR = "#373"
  POSTS_COLOR = "#000"
  TASKS_COLOR = "#D72E2E"
  MEETINGS_COLOR = "#1584D5"
  SURVEY_RESPONSES_COLOR = "#722f37"
  ACTIVITY_COLOR = "#078673"
  NO_ACTIVITY_COLOR = "#d1dade"

  def get_groups_report_table_header(report_view_columns, sort_param, sort_order, start_date, end_date, custom_term_options)
    table_header = get_safe_string
    report_view_columns.each do |column|
      key = column.column_key
      column_header = column.get_title(ReportViewColumn::ReportType::GROUPS_REPORT, custom_term_options)
      html_options = {
        class: "cui-fixed-table-column whitespace-nowrap truncate-with-ellipsis ",
        data: {
          toggle: "tooltip",
          title: column_header
        }
      }
      if column.is_sortable?
        order = (sort_param == key) ? sort_order : "both"
        html_options[:class] += "sort_#{order} pointer cjs_sortable_column"
        html_options[:id] = "sort_by_#{key}"
        html_options[:data].merge!(
          sort_param: key,
          url: groups_report_path(format: :js),
          start_date: start_date,
          end_date: end_date
        )
      end
      html_options[:class] += " text-center" if ReportViewColumn::GroupsReport.activity_columns.include?(key)
      table_header += content_tag(:th, column_header, html_options)
    end
    return table_header
  end

  def get_groups_report_table_totals(report_view_columns, totals_hash)
    totals_row = "".html_safe
    report_view_columns.each do |column|
      key = column.column_key
      html_options = { class: "font-600" }
      group_ids = @current_program.groups.published.pluck(:id)
      if ReportViewColumn::GroupsReport.activity_columns.include?(key)
        html_options[:class] += " text-center"
      end
      totals_row += content_tag(:td, totals_hash[key], html_options)
    end
    return totals_row.html_safe
  end

  def get_groups_report_table_row(group, report_view_columns, groups_report)
    table_row = "".html_safe
    report_view_columns.each do |column|
      html_options = {}
      key = column.column_key

      column_value =
        case key
        when ReportViewColumn::GroupsReport::Key::GROUP
          link_to_if(group.admin_enter_mentoring_connection?(current_user, super_console?), group.name, group_path(group, :root => group.program.root))
        when ReportViewColumn::GroupsReport::Key::MENTORS
          group.mentors.collect{|mentor| link_to_user(mentor, :content_text => display_member_name(mentor.member), :no_hovercard => true)}.to_sentence.html_safe
        when ReportViewColumn::GroupsReport::Key::MENTEES
          group.students.collect{|student| link_to_user(student, :content_text => display_member_name(student.member), :no_hovercard => true)}.to_sentence.html_safe
        when ReportViewColumn::GroupsReport::Key::STARTED_ON
          formatted_time_in_words(group.published_at, :no_ago => true, :no_time => true)
        when ReportViewColumn::GroupsReport::Key::CLOSE_DATE
          closed_or_expiry_time = group.closed_at.present? ? group.closed_at : group.expiry_time
          formatted_time_in_words(closed_or_expiry_time, :no_ago => true, :no_time => true)
        else
          column.get_groups_report_column_data_for_table_row_or_csv(groups_report, group)
        end

      if ReportViewColumn::GroupsReport.activity_columns.include?(key)
        html_options.merge!(class: "text-center")
      end
      table_row += content_tag(:td, column_value, html_options)
    end
    return table_row.html_safe
  end

  def get_groups_status_string(status_filter)
    {
      GroupsController::StatusFilters::Code::ACTIVE => "feature.connection.content.status.active".translate,
      GroupsController::StatusFilters::Code::INACTIVE => "feature.connection.content.status.inactive".translate,
      GroupsController::StatusFilters::Code::CLOSED => "feature.connection.content.status.closed".translate,
      GroupsController::StatusFilters::Code::ONGOING => "feature.connection.content.status.ongoing".translate,
      GroupsController::StatusFilters::Code::DRAFTED => "feature.connection.content.status.drafted".translate,
      GroupsController::StatusFilters::Code::PENDING => "feature.connection.content.status.available".translate,
      GroupsController::StatusFilters::Code::PROPOSED => "feature.connection.content.status.proposed".translate,
      GroupsController::StatusFilters::Code::REJECTED => "feature.connection.content.status.rejected".translate,
      GroupsController::StatusFilters::Code::WITHDRAWN => "feature.connection.content.status.withdrawn".translate
    }[status_filter]
  end

  def get_groups_status_hash
    {
      Group::Status::ACTIVE => "feature.connection.content.status.active".translate,
      Group::Status::INACTIVE => "feature.connection.content.status.inactive".translate,
      Group::Status::CLOSED => "feature.connection.content.status.closed".translate,
      Group::Status::DRAFTED => "feature.connection.content.status.drafted".translate,
      Group::Status::PENDING => "feature.connection.content.status.pending".translate,
      Group::Status::PROPOSED => "feature.connection.content.status.proposed".translate,
      Group::Status::REJECTED => "feature.connection.content.status.rejected".translate,
      Group::Status::WITHDRAWN => "feature.connection.content.status.withdrawn".translate
    }
  end

  def get_groups_status_sorted(order)
    groups_status_hash =get_groups_status_hash
    sorted_hash = (order == "asc" ? Hash[groups_status_hash.sort_by{|_k, v| v}] : Hash[groups_status_hash.sort_by{|_k, v| v}.reverse])
    return sorted_hash.keys
  end

  def format_date_for_view(date)
    DateTime.localize(date, format: :full_display_no_time)
  end

  def get_groups_report_columns_for_multiselect(selected_column_keys, custom_term_options)
    all_columns = ReportViewColumn.get_applicable_groups_report_columns(@current_program).collect do |column_key|
      [ReportViewColumn::GroupsReport.all(custom_term_options)[column_key][:title], column_key]
    end
    options_for_select(all_columns, selected_column_keys)
  end

  def get_groups_report_date_range_options(selected_option)
    options_array = []
    ReportsController::DateRangeOptions.presets.each do |option|
      options_array << ["chronus_date_range_picker_strings.preset_ranges.#{option}".translate, option]
    end
    options_array << ["chronus_date_range_picker_strings.custom".translate, ReportsController::DateRangeOptions::CUSTOM]
    options_for_select(options_array, selected_option)
  end

  def get_groups_report_trend_chart_hash(groups_report)
    groups_activity_trend_chart = ActiveSupport::OrderedHash.new
    if @current_program.group_messaging_enabled?
      groups_activity_trend_chart["messages"] = {
        name: "feature.reports.groups_report_columns.messages_count".translate,
        data: groups_report.messages_by_period.values,
        visible: true,
        color: MESSAGES_COLOR
      }
    end
    if @current_program.group_forum_enabled?
      groups_activity_trend_chart["posts"] = {
        name: "feature.reports.groups_report_columns.posts_count".translate,
        data: groups_report.posts_by_period.values,
        visible: true,
        color: POSTS_COLOR
      }
    end
    if @current_program.mentoring_connections_v2_enabled?
      groups_activity_trend_chart["tasks"] = {
        name: "feature.reports.groups_report_columns.tasks_count".translate,
        data: groups_report.tasks_by_period.values,
        visible: true,
        color: TASKS_COLOR
      }
    end
    if @current_program.mentoring_connection_meeting_enabled?
      groups_activity_trend_chart["meetings"] = {
        name: "feature.reports.groups_report_columns.meetings_count".translate(:Meetings => _Meetings),
        data: groups_report.meetings_by_period.values,
        visible: true,
        color: MEETINGS_COLOR
      }
    end
    if @current_program.mentoring_connections_v2_enabled? && @current_program.surveys.of_engagement_type.present?
      groups_activity_trend_chart["survey_responses"] = {
        name: "feature.survey.label.survey_responses".translate,
        data: groups_report.survey_responses_by_period.values,
        visible: true,
        color: SURVEY_RESPONSES_COLOR
      }
    end
    groups_activity_trend_chart
  end

  def get_groups_report_activity_stats(groups_report)
    total_groups = groups_report.group_ids.size
    groups_report_activity_stats = 
      [{
        name: "feature.reports.content.connection_with_activity".translate(Mentoring_Connections: _Mentoring_Connections),
        y: ((groups_report.activity_groups.to_f/total_groups)*100).round(),
        color: ACTIVITY_COLOR
      },
      {
        name: "feature.reports.content.connection_without_any_activity".translate(Mentoring_Connections: _Mentoring_Connections),
        y: ((groups_report.no_activity_groups.to_f/total_groups)*100).round(),
        color: NO_ACTIVITY_COLOR
      }]
    groups_report_activity_stats
  end
end