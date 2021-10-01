module OutcomesReportHelper
  def get_outcomes_report_date_range_options_details(program_start_date, start_date, end_date)
    details = []
    display_date = ->(date) { DateTime.localize(date, format: :full_display_no_time) }
    backend_date = ->(date) { DateTime.localize(date.to_date, format: :date_range) }
    get_otpions_hsh = ->(key, start_date, end_date, display_date, backend_date) do
      {
        start_date_text: display_date.call(start_date),
        end_date_text: display_date.call(end_date),
        start_date_val: backend_date.call(start_date),
        end_date_val: backend_date.call(end_date),
        option_text: "chronus_date_range_picker_strings.preset_ranges.#{key}".translate,
        custom: false,
        key: key,
        start_date_to_i: start_date.to_i
      }
    end
    details << get_otpions_hsh.call(ReportsController::DateRangeOptions::PROGRAM_TO_DATE, program_start_date, end_date, display_date, backend_date)
    details << get_otpions_hsh.call(ReportsController::DateRangeOptions::MONTH_TO_DATE, end_date.beginning_of_month, end_date, display_date, backend_date)
    details << get_otpions_hsh.call(ReportsController::DateRangeOptions::QUARTER_TO_DATE, end_date.beginning_of_quarter, end_date, display_date, backend_date)
    details << get_otpions_hsh.call(ReportsController::DateRangeOptions::YEAR_TO_DATE, end_date.beginning_of_year, end_date, display_date, backend_date)
    details << get_otpions_hsh.call(ReportsController::DateRangeOptions::LAST_MONTH, end_date.prev_month.beginning_of_month, end_date.prev_month.end_of_month, display_date, backend_date)
    details << get_otpions_hsh.call(ReportsController::DateRangeOptions::LAST_QUARTER, end_date.beginning_of_quarter.previous_week.beginning_of_quarter, end_date.beginning_of_quarter.previous_week.end_of_quarter, display_date, backend_date)
    details << get_otpions_hsh.call(ReportsController::DateRangeOptions::LAST_YEAR, end_date.prev_year.beginning_of_year, end_date.prev_year.end_of_year, display_date, backend_date)
    details << {
      start_date_text: display_date.call(start_date),
      end_date_text: display_date.call(end_date),
      start_date_val: backend_date.call(start_date),
      end_date_val: backend_date.call(end_date),
      option_text: "chronus_date_range_picker_strings.custom".translate,
      custom: true,
      key: ReportsController::DateRangeOptions::CUSTOM,
      start_date_to_i: start_date.to_i
    }
    details
  end

  def get_outcomes_membership_section_total_title
    get_outcomes_common_section_title("feature.outcomes_report.title.user_outcomes_report".translate, "outcomes_report_membership_tooltip", "feature.outcomes_report.tooltip.users_total_v1".translate(program: _program))
  end

  def get_outcomes_matching_section_total_title
    get_outcomes_common_section_title("feature.outcomes_report.title.users_total_connections".translate, "outcomes_report_matching_tooltip", "feature.outcomes_report.tooltip.users_connected".translate(mentoring_connection: _mentoring_connection))
  end

  def get_outcomes_matching_section_total_connections_title
    get_outcomes_common_section_title(_Mentoring_Connections, "outcomes_report_matching_connections_tooltip", "feature.outcomes_report.tooltip.mentoring_connections_total".translate(mentoring_connections: _mentoring_connections))
  end

  def get_outcomes_ongoing_section_total_title
    get_outcomes_common_section_title("feature.outcomes_report.content.total_users".translate, "outcomes_report_ongoing_tooltip", "feature.outcomes_report.tooltip.users_with_completed_mentoring_connections".translate(mentoring_connection: _mentoring_connection))
  end

  def get_outcomes_ongoing_section_total_connections_title
    get_outcomes_common_section_title(_Mentoring_Connections, "outcomes_report_ongoing_connections_tooltip", "feature.outcomes_report.tooltip.mentoring_connections_completed".translate(mentoring_connections: _mentoring_connections))
  end

  def get_outcomes_flash_section_total_title
    get_outcomes_common_section_title("feature.outcomes_report.content.total_users".translate, "outcomes_report_flash_users_tooltip", "feature.outcomes_report.tooltip.users_with_completed_sessions".translate(meeting: _meeting))
  end

  def get_outcomes_flash_section_total_connections_title
    get_outcomes_common_section_title(_Meetings, "outcomes_report_flash_mettings_tooltip", "feature.outcomes_report.tooltip.sessions_completed".translate(meetings: _meetings))
  end

  def get_outcomes_positive_results_for_groups_section_total_title
    get_outcomes_common_section_title("feature.outcomes_report.content.total_users".translate, "outcomes_report_positive_results_tooltip", "feature.outcomes_report.tooltip.users_reporting_positive_results".translate(a_mentoring_connection: _a_mentoring_connection, mentoring_connection: _mentoring_connection))
  end

  def get_outcomes_positive_results_for_flash_section_total_title
    get_outcomes_common_section_title("feature.outcomes_report.content.total_users".translate, "outcomes_report_positive_results_tooltip", "feature.outcomes_report.tooltip.users_reporting_positive_meeting_results".translate(meeting: _meeting, a_meeting: _a_meeting))
  end

  def get_outcomes_positive_results_for_groups_section_total_connections_title
    get_outcomes_common_section_title(_Mentoring_Connections, "outcomes_report_positive_results_total_connections_tooltip", "feature.outcomes_report.tooltip.mentoring_connections_reporting_positive_results".translate(mentoring_connections: _mentoring_connections))
  end

  def get_outcomes_positive_results_for_flash_section_total_connections_title
    get_outcomes_common_section_title(_Meetings, "outcomes_report_positive_results_total_connections_tooltip", "feature.outcomes_report.tooltip.sessions_reporting_positive_results".translate(meetings: _meetings))
  end

  def get_outcomes_common_section_title(title, id, tooltip_text)
    content_tag(:span, title) +
    content_tag(:i, "", class: "fa fa-info-circle small dim m-l-xs", id: id) + 
    tooltip(id, tooltip_text)
  end

  def get_outcomes_progress_bar_tooltip(string_key, role_name, groups_or_meeting_term)
    string_key.translate(percentage: content_tag(:b, "0%", class: "cjs_progress_bar_percent"), groups_or_meetings: groups_or_meeting_term, role_name: role_name)
  end
end