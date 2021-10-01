require_relative './../../test_helper.rb'

class ProjectRequestViewTest < ActiveSupport::TestCase
  def test_count
    program = programs(:pbe)
    ProjectRequest.expects(:get_project_requests_search_count).with({status: "pending", requestor: nil, project: nil}, {program: program, skip_pagination: true}).returns(5)
    view = ProjectRequestView::DefaultViews.create_for(program)[0]
    initial_count = program.project_requests.active.count
    assert_equal initial_count, view.count
  end

  def test_default_views_create_for
    program = programs(:pbe)
    views = ProjectRequestView::DefaultViews.create_for(program)
    assert_equal 1, views.size
    assert_equal_hash({status: AbstractRequest::Status::STATE_TO_STRING[AbstractRequest::Status::NOT_ANSWERED]}, views[0].filter_params_hash)
    assert_equal "feature.abstract_view.pending_request_view.pending_title".translate(program.management_report_related_custom_term_interpolations), views[0].title
    assert_equal "feature.abstract_view.pending_request_view.pending_description".translate(program.management_report_related_custom_term_interpolations), views[0].description
  end

  def test_default_views_create_for_portal
    assert_no_difference 'ProjectRequestView.count' do
      ProjectRequestView::DefaultViews.create_for(programs(:primary_portal))
    end
  end

  def test_get_params_to_service_format
    Timecop.freeze do
      hsh = { status: "active", requestor: "User1", project: "User2" }
      project_request_view = ProjectRequestView.create!(program: programs(:albers), title: "Test", filter_params: AbstractView.convert_to_yaml(hsh))
      assert_equal_hash({status: "active", requestor: "User1", project: "User2"}, project_request_view.get_params_to_service_format)

      hsh = { status: "active", requestor: "User1", project: "User2", sent: { after: 90 } }
      project_request_view.update_attribute(:filter_params, AbstractView.convert_to_yaml(hsh))
      assert_equal (Time.now - 90.days).to_s, project_request_view.get_params_to_service_format[:start_time].to_s
      assert_equal Time.now.to_s, project_request_view.get_params_to_service_format[:end_time].to_s

      hsh = { status: "active", requestor: "User1", project: "User2", sent: { before: 10 } }
      project_request_view.update_attribute(:filter_params, AbstractView.convert_to_yaml(hsh))
      assert_equal DEFAULT_START_TIME.to_s, project_request_view.get_params_to_service_format[:start_time].to_s
      assert_equal (Time.now - 10.days).to_s, project_request_view.get_params_to_service_format[:end_time].to_s

      hsh = { status: "active", requestor: "User1", project: "User2", sent: { before: 10, after: 90 } }
      project_request_view.update_attribute(:filter_params, AbstractView.convert_to_yaml(hsh))
      assert_equal (Time.now - 90.days).to_s, project_request_view.get_params_to_service_format[:start_time].to_s
      assert_equal (Time.now - 10.days).to_s, project_request_view.get_params_to_service_format[:end_time].to_s
    end
  end

  def test_is_accessible
    program = programs(:albers)
    assert_false ProjectRequestView.is_accessible?(program)

    program.update_attribute(:engagement_type, Program::EngagementType::PROJECT_BASED)
    assert ProjectRequestView.is_accessible?(program)
  end
end