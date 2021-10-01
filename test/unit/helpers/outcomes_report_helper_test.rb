require_relative './../../test_helper.rb'

class OutcomesReportHelperTest < ActionView::TestCase
  include TranslationsService

  def test_get_outcomes_report_date_range_options_details
    program_start_date, start_date, end_date = [Time.zone.local(2014), Time.zone.local(2014, 8), Time.zone.local(2014, 9)]
    ret = get_outcomes_report_date_range_options_details(program_start_date, start_date, end_date)
    assert_equal [
      {:start_date_text=>"January 01, 2014", :end_date_text=>"September 01, 2014", :start_date_val=>"01/01/2014", :end_date_val=>"09/01/2014", :option_text=>"Program start to date", :custom=>false, :key=>"program_to_date", :start_date_to_i => DateTime.parse("January 01, 2014").to_i},
      {:start_date_text=>"September 01, 2014", :end_date_text=>"September 01, 2014", :start_date_val=>"09/01/2014", :end_date_val=>"09/01/2014", :option_text=>"Month to date", :custom=>false, :key=>"month_to_date", :start_date_to_i => DateTime.parse("September 01, 2014").to_i},
      {:start_date_text=>"July 01, 2014", :end_date_text=>"September 01, 2014", :start_date_val=>"07/01/2014", :end_date_val=>"09/01/2014", :option_text=>"Quarter to date", :custom=>false, :key=>"quarter_to_date", :start_date_to_i => DateTime.parse("July 01, 2014").to_i},
      {:start_date_text=>"January 01, 2014", :end_date_text=>"September 01, 2014", :start_date_val=>"01/01/2014", :end_date_val=>"09/01/2014", :option_text=>"Year to date", :custom=>false, :key=>"year_to_date", :start_date_to_i => DateTime.parse("January 01, 2014").to_i},
      {:start_date_text=>"August 01, 2014", :end_date_text=>"August 31, 2014", :start_date_val=>"08/01/2014", :end_date_val=>"08/31/2014", :option_text=>"Last Month", :custom=>false, :key=>"last_month", :start_date_to_i => DateTime.parse("August 01, 2014").to_i},
      {:start_date_text=>"April 01, 2014", :end_date_text=>"June 30, 2014", :start_date_val=>"04/01/2014", :end_date_val=>"06/30/2014", :option_text=>"Last Quarter", :custom=>false, :key=>"last_quarter", :start_date_to_i => DateTime.parse("April 01, 2014").to_i},
      {:start_date_text=>"January 01, 2013", :end_date_text=>"December 31, 2013", :start_date_val=>"01/01/2013", :end_date_val=>"12/31/2013", :option_text=>"Last Year", :custom=>false, :key=>"last_year", :start_date_to_i => DateTime.parse("January 01, 2013").to_i},
      {:start_date_text=>"August 01, 2014", :end_date_text=>"September 01, 2014", :start_date_val=>"08/01/2014", :end_date_val=>"09/01/2014", :option_text=>"Custom", :custom=>true, :key=>"custom", :start_date_to_i => DateTime.parse("August 01, 2014").to_i}
    ], ret
  end

  def test_get_outcomes_common_section_title
    self.stubs(:tooltip).with("some_id", "some tooltip text").returns("TOOLTIP").once
    html_content = to_html(get_outcomes_common_section_title("some title", "some_id", "some tooltip text"))
    assert_select html_content, "span", text: "some title"
    assert_select html_content, "i#some_id"
    assert_equal html_content.text, "some titleTOOLTIP"
  end

  def test_get_outcomes_membership_section_total_title
    self.stubs(:get_outcomes_common_section_title).with("feature.outcomes_report.title.user_outcomes_report".translate, "outcomes_report_membership_tooltip", "feature.outcomes_report.tooltip.users_total_v1".translate(program: _program)).returns("something").once
    assert_equal "something", get_outcomes_membership_section_total_title
  end

  def test_get_outcomes_matching_section_total_title
    self.stubs(:get_outcomes_common_section_title).with("feature.outcomes_report.title.users_total_connections".translate, "outcomes_report_matching_tooltip", "feature.outcomes_report.tooltip.users_connected".translate(mentoring_connection: _mentoring_connection)).returns("something").once
    assert_equal "something", get_outcomes_matching_section_total_title
  end

  def test_get_outcomes_matching_section_total_connections_title
    self.stubs(:get_outcomes_common_section_title).with(_Mentoring_Connections, "outcomes_report_matching_connections_tooltip", "feature.outcomes_report.tooltip.mentoring_connections_total".translate(mentoring_connections: _mentoring_connections)).returns("something").once
    assert_equal "something", get_outcomes_matching_section_total_connections_title
  end

  def test_get_outcomes_ongoing_section_total_title
    self.stubs(:get_outcomes_common_section_title).with("feature.outcomes_report.content.total_users".translate, "outcomes_report_ongoing_tooltip", "feature.outcomes_report.tooltip.users_with_completed_mentoring_connections".translate(mentoring_connection: _mentoring_connection)).returns("something").once
    assert_equal "something", get_outcomes_ongoing_section_total_title
  end

  def test_get_outcomes_ongoing_section_total_connections_title
    self.stubs(:get_outcomes_common_section_title).with(_Mentoring_Connections, "outcomes_report_ongoing_connections_tooltip", "feature.outcomes_report.tooltip.mentoring_connections_completed".translate(mentoring_connections: _mentoring_connections)).returns("something").once
    assert_equal "something", get_outcomes_ongoing_section_total_connections_title
  end

  def test_get_outcomes_flash_section_total_title
    self.stubs(:get_outcomes_common_section_title).with("feature.outcomes_report.content.total_users".translate, "outcomes_report_flash_users_tooltip", "feature.outcomes_report.tooltip.users_with_completed_sessions".translate(meeting: _meeting)).returns("something").once
    assert_equal "something", get_outcomes_flash_section_total_title
  end

  def test_get_outcomes_flash_section_total_connections_title
    self.stubs(:get_outcomes_common_section_title).with(_Meetings, "outcomes_report_flash_mettings_tooltip", "feature.outcomes_report.tooltip.sessions_completed".translate(meetings: _meetings)).returns("something").once
    assert_equal "something", get_outcomes_flash_section_total_connections_title
  end

  def test_get_outcomes_positive_results_for_groups_section_total_title
    self.stubs(:get_outcomes_common_section_title).with("feature.outcomes_report.content.total_users".translate, "outcomes_report_positive_results_tooltip", "feature.outcomes_report.tooltip.users_reporting_positive_results".translate(a_mentoring_connection: _a_mentoring_connection, mentoring_connection: _mentoring_connection)).returns("something").once
    assert_equal "something", get_outcomes_positive_results_for_groups_section_total_title
  end

  def test_get_outcomes_positive_results_for_flash_section_total_title
    self.stubs(:get_outcomes_common_section_title).with("feature.outcomes_report.content.total_users".translate, "outcomes_report_positive_results_tooltip", "feature.outcomes_report.tooltip.users_reporting_positive_meeting_results".translate(meeting: _meeting, a_meeting: _a_meeting)).returns("something").once
    assert_equal "something", get_outcomes_positive_results_for_flash_section_total_title
  end

  def test_get_outcomes_positive_results_for_groups_section_total_connections_title
    self.stubs(:get_outcomes_common_section_title).with(_Mentoring_Connections, "outcomes_report_positive_results_total_connections_tooltip", "feature.outcomes_report.tooltip.mentoring_connections_reporting_positive_results".translate(mentoring_connections: _mentoring_connections)).returns("something").once
    assert_equal "something", get_outcomes_positive_results_for_groups_section_total_connections_title
  end

  def test_get_outcomes_positive_results_for_flash_section_total_connections_title
    self.stubs(:get_outcomes_common_section_title).with(_Meetings, "outcomes_report_positive_results_total_connections_tooltip", "feature.outcomes_report.tooltip.sessions_reporting_positive_results".translate(meetings: _meetings)).returns("something").once
    assert_equal "something", get_outcomes_positive_results_for_flash_section_total_connections_title
  end

  def test_get_outcomes_progress_bar_tooltip
    string = "some string"
    self.stubs(:content_tag).with(:b, "0%", class: "cjs_progress_bar_percent").returns("percent html").once
    string.stubs(:translate).with(percentage: "percent html", groups_or_meetings: "groups_or_meeting_term", role_name: "role name").returns("result").once
    assert_equal "result", get_outcomes_progress_bar_tooltip(string, 'role name', 'groups_or_meeting_term')
  end

  private

  def _program
    "program"
  end

  def _Meetings
    "Meetings"
  end

  def _meetings
    "meetings"
  end

  def _a_meeting
    "a meeting"
  end

  def _Mentoring_Connections
    "Mentoring Connections"
  end

  def _mentoring_connection
    "mentoring connection"
  end

  def _a_mentoring_connection
    "a mentoring connection"
  end
end