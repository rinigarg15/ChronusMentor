require_relative './../../test_helper.rb'

class ReportsHelperTest < ActionView::TestCase

  include MeetingsHelper
	
  def test_get_activity_report_dropdown_options
    start_time = Time.now
    end_time = start_time + 30.minutes

    content = get_activity_report_dropdown_options(["mentor","student"], start_time, end_time)
    assert_equal 2, content.count
    assert_equal "CSV", content.first[:label]
    assert_equal "PDF", content.last[:label]
    assert_equal "fa fa-file-excel-o", content.first[:icon]
    assert_equal "fa fa-file-pdf-o", content.last[:icon]
    assert_equal "/reports/activity_report.csv?date_range_filter=#{start_time.strftime('%m')}%2F#{start_time.strftime('%d')}%2F#{start_time.strftime('%Y')}+-+#{end_time.strftime('%m')}%2F#{end_time.strftime('%d')}%2F#{end_time.strftime('%Y')}&role_filters%5B%5D=mentor&role_filters%5B%5D=student", content.first[:url]
    assert_equal "/reports/activity_report.pdf?date_range_filter=#{start_time.strftime('%m')}%2F#{start_time.strftime('%d')}%2F#{start_time.strftime('%Y')}+-+#{end_time.strftime('%m')}%2F#{end_time.strftime('%d')}%2F#{end_time.strftime('%Y')}&role_filters%5B%5D=mentor&role_filters%5B%5D=student", content.last[:url]
  end

  def test_get_executive_summary_report_dropdown_options
    content = get_executive_summary_report_dropdown_options
    assert_equal 1, content.count
    assert_equal "PDF", content.first[:label]
    assert_equal "fa fa-file-pdf-o", content.first[:icon]
    assert_equal "/reports/executive_summary.pdf", content.first[:url]
  end

  def test_get_health_report_dropdown_options
    content = get_health_report_dropdown_options
    assert_equal 1, content.count
    assert_equal "PDF", content.first[:label]
    assert_equal "fa fa-file-pdf-o", content.first[:icon]
    assert_equal "/reports/health_report.pdf", content.first[:url]
  end

  def test_get_alert_filter_for_display
    program = programs(:albers)
    view = program.abstract_views.where(default_view: AbstractView::DefaultType::PENDING_REQUESTS).first
    metric = view.metrics.first
    data = get_alert_filter_for_display(metric, nil, "cjs_alert_filter_params_0")
    assert_match "<option data-url=\"/report/alerts/get_options.js?filter_name=&amp;index=cjs_alert_filter_params_0&amp;view_id=#{view.id}\" value=\"\">Select...</option>", data
    assert_match "<option data-url=\"/report/alerts/get_options.js?filter_name=sent_between&amp;index=cjs_alert_filter_params_0&amp;view_id=#{view.id}\" value=\"sent_between\">Sent On</option>", data
    view = programs(:no_mentor_request_program).abstract_views.where(default_view: AbstractView::DefaultType::DRAFTED_CONNECTIONS).first
    metric = view.metrics.first
    error = assert_raise(RuntimeError) do
      get_alert_filter_for_display(metric, nil, "cjs_alert_filter_params_0")
    end
    assert_equal "Filter called for non-supported views", error.message
  end

  def test_get_alert_filter_operator_for_display
    program = programs(:albers)
    view = program.abstract_views.where(default_view: AbstractView::DefaultType::PENDING_REQUESTS).first
    data = get_alert_filter_operator_for_display(view, "", "cjs_alert_filter_params_0")
    assert_match "<option value=\"\">Select...<\/option>", data
    data = get_alert_filter_operator_for_display(view, FilterUtils::MembershipRequestViewFilters::SENT_BETWEEN, "cjs_alert_filter_params_0")
    assert_match "<option value=\"\">Select...<\/option>", data
    assert_match "<option value=\"in_last\">In Last<\/option>", data
    assert_match "<option value=\"before_last\">Before Last<\/option>", data
  end

  def test_filter_metrics_based_on_mentoring_style
    program = programs(:albers)
    metrics = program.report_sections.collect(&:metrics).flatten
    assert metrics.collect(&:title).include?("Pending Mentoring Requests")

    # ongoing enabled and cases where mentor requests are enabled and disabled
    assert program.ongoing_mentoring_enabled?
    program.update_column(:mentor_request_style, Program::MentorRequestStyle::MENTEE_TO_MENTOR)
    filtered_metrics = filter_metrics_based_on_mentoring_style(program, metrics)
    assert filtered_metrics.collect(&:title).include?("Pending Mentoring Requests")
    program.update_column(:mentor_request_style, Program::MentorRequestStyle::NONE)
    filtered_metrics = filter_metrics_based_on_mentoring_style(program, metrics)
    assert_false filtered_metrics.collect(&:title).include?("Pending Mentoring Requests")

    #disabling ongoing mentoring
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    filtered_metrics = filter_metrics_based_on_mentoring_style(program, metrics)
    assert_false filtered_metrics.collect(&:title).include?("Pending Mentoring Requests")

    #changing default_metric of a existing metric to test when onetime is disabled
    metric = metrics[0]
    metric.update_attribute(:default_metric, Report::Metric::DefaultMetrics::PENDING_MEETING_REQUESTS)
    filtered_metrics = filter_metrics_based_on_mentoring_style(program, metrics)
    assert_false filtered_metrics.include?(metric)
  end

  def test_get_reports_time_filter
    assert_equal "Jan 10, 2016 - Mar 15, 2016", get_reports_time_filter({start: "10/1/2016".to_date, end: "15/3/2016".to_date})
    assert_equal "Jan 2016 - Mar 2016", get_reports_time_filter({start: "10/1/2016".to_date, end: "15/3/2016".to_date}, header_date_format: "%b %Y")
  end

  def test_get_reports_export_options
    one_option = [{label: "Export to XLS", url: calendar_sessions_path(format: :xls), data: {fruit: 'apple', url: 'something'}}]
    two_options = [{label: "Export to XLS", url: calendar_sessions_path(format: :xls), data: {fruit: 'apple', url: 'something'}}, {label: "Export to PDF", url: 'something-else', class: "nothing"}]

    html_content_1 = to_html get_reports_export_options(one_option)
    assert_select html_content_1, "a[href=?][data-fruit='apple'][data-url='something'].pull-right.m-l-sm.m-r-sm.big.cjs-reports-export-options", calendar_sessions_path(format: :xls) do
      assert_select "span" do
        assert_select "i.fa.fa-download.no-margins"
      end
      assert_select "span.sr-only", count: 1, text: "Export to XLS"
    end

    html_content_2 = to_html get_reports_export_options(two_options)
    assert_select html_content_2, "div#cjs_reports_export.dropdown" do
      assert_select "a[href=?].dropdown-toggle.no-waves", "javascript:void(0)" do
        assert_select "span" do
          assert_select "i.fa.fa-download.no-margins"
        end
      end
      assert_select "ul.dropdown-menu" do
        assert_select "li", count: 2
        assert_select "a[href=?][data-fruit='apple'][data-url='something'].cjs-reports-export-options", calendar_sessions_path(format: :xls)
        assert_select "a[href=?][data-url='something-else'].nothing.cjs-reports-export-options", "something-else"
      end
    end
  end

  def test_get_report_actions_modal_footer_content
    set_response_text get_report_actions_modal_footer_content

    assert_select "div.pull-right" do
      assert_select "a.cjs_other_filters_cancel", :href => "javascript:void(0)", :text => "Cancel"
      assert_select "a.cjs_other_filters_reset", :href => "javascript:void(0)", :text => "Reset"
      assert_select "input.cjs-report-other-filters-submit", :href => "javascript:void(0)", :value => "Go", :type => "submit"
    end
  end

  def test_render_reports_from_collection
    report_hash = Report::Customization::ReportItem::REPORTS_CONFIG["program_survey"]
    program = programs(:albers)

    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, false)
    set_response_text render_reports_from_collection(report_hash, program)

    assert_select "div.clearfix.container-fluid", count: 0
    assert_select "div.p-md.text-center", text: "You do not have any surveys with responses! Only surveys with responses will be listed here."
  end

  private

  def _Mentoring_Connection
    "Mentoring Connection"
  end

end