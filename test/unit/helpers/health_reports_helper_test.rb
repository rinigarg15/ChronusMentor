require_relative './../../test_helper.rb'
require_relative "./../../../app/helpers/health_reports_helper"

class HealthReportsHelperTest < ActiveSupport::TestCase
  include ActionView::Helpers::TextHelper
  include HealthReportsHelper

  def setup
    super
    helper_setup
  end

  def test_metric_value_string
    metric = HealthReport::PercentMetric.new(0.5)
    metric.expects(:value).returns(0.6)
    assert_equal "60%", metric_value_string(metric)

    metric.expects(:value).returns(0.649)
    assert_equal "65%", metric_value_string(metric)

    metric.minimum = 0
    metric.maximum = 8
    metric.unit = 'day'
    metric.expects(:value).returns(0.5)
    assert_equal "4.0 days", metric_value_string(metric)

    metric.minimum = 0
    metric.maximum = 1
    metric.unit = nil
    metric.expects(:value).returns(0.61)
    assert_equal "6 of 10 points", metric_value_string(metric, true)

    metric.expects(:value).returns(0.39)
    assert_equal "4 of 10 points", metric_value_string(metric, true)
  end

  def test_health_report_growth_chart_data
    program = programs(:albers)
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED_WITH_ONGOING)
    program.reload

    report = HealthReport::Base.new(program)
    report.growth.compute_summary_data
    data = health_report_growth_chart_data(report.growth)

    assert_equal ({:name => "Mentors", :data => report.growth.graph_data["mentor"], :visible=>true}), data["mentor"]
    assert_equal ({:name => "Students", :data => report.growth.graph_data["student"], :visible=>true}), data["student"]
    assert_equal ({:name => "Users", :data => report.growth.graph_data["user"], :visible=>true}), data["user"]
    assert_equal ({:name=> "Mentoring Connections", :data => report.growth.graph_data[:connection], :visible=>true}), data[:connection]
  end

  def test_health_report_growth_chart_data_when_ongoing_mentoring_is_disabled
    program = programs(:albers)
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    program.reload

    report = HealthReport::Base.new(program)
    report.growth.compute_summary_data
    data = health_report_growth_chart_data(report.growth)

    assert_equal ({:name => "Mentors", :data => report.growth.graph_data["mentor"], :visible=>true}), data["mentor"]
    assert_equal ({:name => "Students", :data => report.growth.graph_data["student"], :visible=>true}), data["student"]
    assert_equal ({:name => "Users", :data => report.growth.graph_data["user"], :visible=>true}), data["user"]
    assert_false data[:connection].present?
  end

  def test_health_report_mode_chart_data
    program = programs(:albers)
    report = HealthReport::Base.new(program)

    assert_equal ({render_to: 'health_report_mode_chart', percentage: true, height: 210, data: [["Online", 0.0], ["Chat", 0.0], ["Phone", 0.0], ["Email", 0.0], ["Face-to-Face", 0.0]]}), health_report_mode_chart_data(report.engagement)
  end

  def test_translated_health_report_content_name
    name = "resources"
    assert_match translated_health_report_content_name(name), "feature.reports.label.resources_rated_helpful".translate(:resources => _resources, :program => _program)
  end

  private

  def _Mentors
    "Mentors"
  end

  def _Mentees
    "Mentees"
  end

  def _Mentor
    "Mentor"
  end

  def _Mentee
    "Mentee"
  end

  def _Mentoring_Connections
    "Mentoring Connections"
  end

  def _resources
    "resources"
  end

  def _program
    "program"
  end
end