require_relative './../../test_helper.rb'

class Report::MetricTest < ActiveSupport::TestCase
  def setup
    super
    @program = programs(:albers)
    @view = @program.abstract_views.first
    @section = @program.report_sections.create(title: "Users", description: "All users metrics")
    @metric = @section.metrics.create(title: "pending users", description: "see pending users counts", abstract_view_id: @view.id)
  end

  def test_count
    view = programs(:albers).admin_views.default.find_by(default_view: AbstractView::DefaultType::ALL_USERS)
    metric = Report::Metric.create(title: "title", abstract_view_id: view.id)
    assert_equal view.count, metric.count
  end

  def test_program
    assert_equal @program, @metric.program
    assert_equal @program, @metric.section.program
    assert_equal @program, @metric.abstract_view.program
  end

  def test_abstract_view_belongs_to_section_program_validation
    @metric.abstract_view = programs(:ceg).abstract_views.first
    @metric.save
    assert_equal @program, @metric.program
    assert_equal @metric.errors.messages, {abstract_view_id: ["is not a view in this program"]}
  end

  def test_associations
    assert_equal [], @metric.alerts
    alert = @metric.alerts.create(description: "Some Description", filter_params: "", operator: Report::Alert::OperatorType::LESS_THAN, target: 10)
    assert_equal @metric.alerts, [alert]
    assert_difference "Report::Alert.count", -1 do
      @metric.destroy
    end
  end

  def test_alert
    assert_nil @metric.alert

    alert = @metric.alerts.create!(description: "Some Description", filter_params: "", operator: Report::Alert::OperatorType::LESS_THAN, target: 10)
    assert_equal alert, @metric.alert

    @metric.alerts.create!(description: "Something else", filter_params: "", operator: Report::Alert::OperatorType::LESS_THAN, target: 10)
    assert_equal alert, @metric.alert
  end

  def test_alert_specific_count_needed
    assert_false @metric.alert_specific_count_needed?

    @metric.stubs(:alert).returns("")
    assert @metric.alert_specific_count_needed?

    @metric.abstract_view.stubs(:class).returns(ConnectionView)
    assert_false @metric.alert_specific_count_needed?

    @metric.abstract_view.stubs(:class).returns(ProjectRequestView)
    assert_false @metric.alert_specific_count_needed?

    @metric.abstract_view.stubs(:class).returns(FlagView)
    assert_false @metric.alert_specific_count_needed?

    @metric.abstract_view.stubs(:class).returns(AdminView)
    assert @metric.alert_specific_count_needed?
  end

  def test_update_metric_abstract_view_type
    alert = @metric.alerts.create(description: "Some Description", filter_params: "", operator: Report::Alert::OperatorType::LESS_THAN, target: 10)
    alert.update_attributes!(filter_params: { "cjs_alert_filter_params_0" => { "name" => "4", "operator" => "before_last", "value" => 30 } }.to_yaml)
    existing_abstract_view_type = @metric.abstract_view.type
    @metric.abstract_view = @program.abstract_views.where.not(type: existing_abstract_view_type).first
    @metric.save!
    assert_nil alert.reload.filter_params
  end
end