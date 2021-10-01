require_relative './../../test_helper.rb'

class Report::AlertsControllerTest < ActionController::TestCase

  def test_new
    current_user_is :f_admin
    section = report_sections(:report_section_1)
    metric = report_metrics(:report_metric_1)
    get :new, params: { section_id: section.id, metric_id: metric.id }
    assert_equal section, assigns(:section)
    assert_dynamic_expected_nil_or_equal section.tile, assigns(:tile)
    assert_equal metric, assigns(:metric)
    assert_equal metric, assigns(:alert).metric
    assert assigns(:alert).new_record?
  end

  def test_new_permission_denied
    current_user_is :f_mentor
    assert_permission_denied do
      get :new, params: { section_id: report_sections(:report_section_1).id, metric_id: report_metrics(:report_metric_1).id }
    end
  end

  def test_create
    current_user_is :f_admin
    section = report_sections(:report_section_1)
    metric = report_metrics(:report_metric_1)
    assert_difference('Report::Alert.count', +1) do
      post :create, xhr: true, params: { section_id: section.id, metric_id: metric.id, report_alert: {target: 20, description: "alert2 description", operator: Report::Alert::OperatorType::LESS_THAN}}
    end
    assert_equal section, assigns(:section)
    assert_dynamic_expected_nil_or_equal section.tile, assigns(:tile)
    assert_equal metric, assigns(:metric)
    alert = assigns(:alert)
    assert_equal 20, alert.target
    assert_equal "alert2 description", alert.description
    assert_equal metric, alert.metric
    assert_equal Report::Alert::OperatorType::LESS_THAN, alert.operator
  end

  def test_create_permission_denied
    current_user_is :f_mentor
    assert_permission_denied do
      post :create, params: { section_id: report_sections(:report_section_1).id, metric_id: report_metrics(:report_metric_1).id }
    end
  end

  def test_edit
    current_user_is :f_admin
    section = report_sections(:report_section_1)
    metric = report_metrics(:report_metric_1)
    alert = report_alerts(:report_alert_1)
    get :edit, params: { section_id: section.id, metric_id: metric.id, id: alert.id }
    assert_equal section, assigns(:section)
    assert_dynamic_expected_nil_or_equal section.tile, assigns(:tile)
    assert_equal metric, assigns(:metric)
    assert_equal alert, assigns(:alert)
  end

  def test_edit_permission_denied
    current_user_is :f_mentor
    assert_permission_denied do
      get :edit, params: { id: report_alerts(:report_alert_1).id, section_id: report_sections(:report_section_1).id, metric_id: report_metrics(:report_metric_1).id }
    end
  end

  def test_update
    current_user_is :f_admin
    section = report_sections(:report_section_1)
    metric = report_metrics(:report_metric_1)
    alert = report_alerts(:report_alert_1)
    assert_no_difference('Report::Metric.count') do
      put :update, xhr: true, params: { section_id: section.id, metric_id: metric.id, id: alert.id, report_alert: {target: 5000, description: "new alert description", operator: Report::Alert::OperatorType::LESS_THAN}}
    end
    assert_equal section, assigns(:section)
    assert_dynamic_expected_nil_or_equal section.tile, assigns(:tile)
    assert_equal metric, assigns(:metric)
    alert = assigns(:alert)
    assert_equal 5000, alert.target
    assert_equal "new alert description", alert.description
    assert_equal metric, alert.metric
    assert_equal Report::Alert::OperatorType::LESS_THAN, alert.operator
  end

  def test_update_permission_denied
    current_user_is :f_mentor
    assert_permission_denied do
      put :update, xhr: true, params: { id: report_alerts(:report_alert_1).id, section_id: report_sections(:report_section_1).id, metric_id: report_metrics(:report_metric_1) }
    end
  end

  def test_destroy
    current_user_is :f_admin
    section = report_sections(:report_section_1)
    metric = report_metrics(:report_metric_1)
    alert = report_alerts(:report_alert_1)
    assert_equal [alert], metric.alerts
    assert_difference('Report::Alert.count', -1) do
      delete :destroy, xhr: true, params: { section_id: section.id, metric_id: metric.id, id: alert.id}
    end
    assert_dynamic_expected_nil_or_equal section.tile, assigns(:tile)
    assert metric.reload.alerts.empty?
  end

  def test_destroy_permission_denied
    current_user_is :f_mentor
    assert_permission_denied do
      delete :destroy, xhr: true, params: { id: report_alerts(:report_alert_1).id, section_id: report_sections(:report_section_1).id, metric_id: report_metrics(:report_metric_1).id }
    end
  end

  def test_get_options_permission_denied
    current_user_is :f_mentor
    assert_permission_denied {get :get_options}
  end

  def test_get_options_with_blank_filter
    current_user_is :f_admin
    program = programs(:albers)
    view = program.abstract_views.where(default_view: AbstractView::DefaultType::PENDING_REQUESTS).first

    get :get_options, xhr: true, params: { view_id: view.id, filter_name: ""}
    assert_equal view, assigns(:view)
    assert_equal "", assigns(:filter_name)
  end

  def test_get_options
    current_user_is :f_admin
    program = programs(:albers)
    view = program.abstract_views.where(default_view: AbstractView::DefaultType::PENDING_REQUESTS).first

    get :get_options, xhr: true, params: { view_id: view.id, filter_name: FilterUtils::MembershipRequestViewFilters::SENT_BETWEEN, index: "cjs_alert_filter_params_3"}
    assert_equal view, assigns(:view)
    assert_equal FilterUtils::MembershipRequestViewFilters::SENT_BETWEEN, assigns(:filter_name)
    assert_equal "cjs_alert_filter_params_3", assigns(:index)
  end

  def test_create_with_filters
    current_user_is :f_admin
    section = report_sections(:report_section_1)
    metric = report_metrics(:report_metric_1)
    assert_difference 'Report::Alert.count' do
      post :create, xhr: true, params: { section_id: section.id, metric_id: metric.id, report_alert: {target: 20, description: "alert2 description", operator: Report::Alert::OperatorType::LESS_THAN, filter_params: { cjs_alert_filter_params_0: { name: FilterUtils::AdminViewFilters::FILTERS.first[1][:value], operator: FilterUtils::DateRange::IN_LAST, value: "10" } } } }
    end
    assert_equal section, assigns(:section)
    assert_dynamic_expected_nil_or_equal section.tile, assigns(:tile)
    assert_equal metric, assigns(:metric)
    alert = assigns(:alert)
    assert_equal 20, alert.target
    assert_equal "alert2 description", alert.description
    assert_equal metric, alert.metric
    assert_equal Report::Alert::OperatorType::LESS_THAN, alert.operator
    assert_equal FilterUtils::AdminViewFilters::FILTERS.first[1][:value], alert.filter_params_hash[:cjs_alert_filter_params_0][:name]
    assert_equal FilterUtils::DateRange::IN_LAST, alert.filter_params_hash[:cjs_alert_filter_params_0][:operator]
    assert_equal "10", alert.filter_params_hash[:cjs_alert_filter_params_0][:value]
  end

  def test_update_with_filters
    current_user_is :f_admin
    section = report_sections(:report_section_1)
    metric = report_metrics(:report_metric_1)
    alert = report_alerts(:report_alert_1)
    assert_no_difference('Report::Metric.count') do
      put :update, xhr: true, params: { section_id: section.id, metric_id: metric.id, id: alert.id, report_alert: {target: 5000, description: "new alert description", operator: Report::Alert::OperatorType::LESS_THAN, filter_params: { cjs_alert_filter_params_0: { name: FilterUtils::AdminViewFilters::FILTERS.first[1][:value], operator: FilterUtils::DateRange::IN_LAST, value: "10" } } } }
    end
    assert_equal section, assigns(:section)
    assert_dynamic_expected_nil_or_equal section.tile, assigns(:tile)
    assert_equal metric, assigns(:metric)
    alert = assigns(:alert)
    assert_equal 5000, alert.target
    assert_equal "new alert description", alert.description
    assert_equal metric, alert.metric
    assert_equal Report::Alert::OperatorType::LESS_THAN, alert.operator
    assert_equal FilterUtils::AdminViewFilters::FILTERS.first[1][:value], alert.filter_params_hash[:cjs_alert_filter_params_0][:name]
    assert_equal FilterUtils::DateRange::IN_LAST, alert.filter_params_hash[:cjs_alert_filter_params_0][:operator]
    assert_equal "10", alert.filter_params_hash[:cjs_alert_filter_params_0][:value]
  end
end