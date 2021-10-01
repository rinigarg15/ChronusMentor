require_relative './../../test_helper.rb'

class Report::MetricsControllerTest < ActionController::TestCase
  def setup
    super
    report_role = create_role(name: 'report_role')
    add_role_permission(report_role, 'view_reports')
    @report_manager = create_user(role_names: ['report_role'])
    @program = programs(:albers)
    @view = @program.abstract_views.first
    @sections = @program.report_sections
    @section = report_sections(:report_sections_1)
    @tile = @section.tile
    @metric = @section.metrics.create(title: "pending users", description: "see pending users counts", abstract_view_id: @view.id)
  end

  def test_new
    custom_login
    get :new, params: { section_id: @section.id}
    assert_equal @sections, assigns(:sections)
    assert assigns(:metric).new_record?
    assert_equal @section.id, assigns(:metric).section_id
    assert_equal @section, assigns(:section)
    assert_equal @tile, assigns(:tile)
  end

  def test_create
    custom_login
    @view = @program.abstract_views.where(default_view: AbstractView::DefaultType::PENDING_REQUESTS).first
    assert_difference('Report::Metric.count', 1) do
      post :create, xhr: true, params: { section_id: @section.id, report_metric: {title: "Harry potter" ,description: "dust of appearance", abstract_view_id: @view.id}}
    end
    metric = assigns(:metric)
    assert_equal "Harry potter", metric.title
    assert_equal @sections, assigns(:sections)
    assert_equal "dust of appearance", metric.description
    assert_equal @section, metric.section
    assert_equal @tile, assigns(:tile)
    assert_equal @program, metric.program
    assert_equal @view, metric.abstract_view
    assert_nil assigns(:alert)
  end

  def test_edit
    custom_login
    get :edit, params: { section_id: @section.id, id: @metric.id}
    assert_equal @sections, assigns(:sections)
    assert_equal @metric, assigns(:metric)

    subview_optgroups = assigns(:subview_optgroups)

    view_weights = []
    subview_optgroups.each do |view|
      view_weights << AbstractView::DefaultOrder::WEIGHTS["#{view}"]
    end
    assert_equal view_weights, view_weights.sort
    assert_equal @section, @metric.section
    assert_equal @tile, assigns(:tile)
  end

  def test_update
    custom_login
    other_view = @program.abstract_views.where(default_view: AbstractView::DefaultType::PENDING_REQUESTS).first
    assert_not_equal @view, other_view
    assert_no_difference('Report::Metric.count') do
      put :update, xhr: true, params: { id: @metric.id, section_id: @section.id, report_metric: {title: "check 123", description: "dust of appearance", abstract_view_id: other_view.id}}
    end
    metric = assigns(:metric)
    assert_equal "check 123", metric.title
    assert_equal "dust of appearance", metric.description
    assert_equal @sections, assigns(:sections)
    assert_equal @program, metric.program
    assert_equal other_view, metric.abstract_view
    assert_equal @tile, assigns(:tile)
  end

  def test_destroy
    custom_login
    assert_difference('Report::Metric.count', -1) do
      delete :destroy, xhr: true, params: { section_id: @section.id, id: @metric.id, section_counter: "0"}
    end
    assert Report::Metric.where(id: @metric.id).empty?
    assert_equal @tile, assigns(:tile)
  end

  def test_accessible_subview_optgroups
    custom_login
    get :new, params: { section_id: @section.id }
    assert_equal_unordered ["AdminView", "ConnectionView", "FlagView"], assigns(:subview_optgroups).collect(&:name)
  end

  def test_available_abstract_views
    custom_login
    view = @program.abstract_views.where(default_view: AbstractView::DefaultType::MENTORS).first
    get :new, params: { section_id: @section.id}
    assert assigns(:subview_optgroups).map(&:available_sub_views_for_current_program).flatten.include?(view)
    added_metric = create_report_metric({ title: "Harry potter", description: "dust of appearance", abstract_view_id: view.id, section_id: @section.id })
    get :new, params: { section_id: @section.id}
    assert_false assigns(:subview_optgroups).map(&:available_sub_views_for_current_program).flatten.include?(view)
    added_metric.destroy
    get :new, params: { section_id: @section.id}
    assert assigns(:subview_optgroups).map(&:available_sub_views_for_current_program).flatten.include?(view)
  end

  def test_accessible_subview_optgroups_flag_disabled
    custom_login
    disable_feature(programs(:albers), FeatureName::FLAGGING)
    get :new, params: { section_id: @section.id}
    assert_false assigns(:subview_optgroups).collect(&:name).include?("FlagView")
  end

  def test_accessible_subview_optgroups_membership_disabled
    custom_login
    programs(:albers).roles.update_all(membership_request: false)
    programs(:albers).roles.update_all(join_directly: false)
    get :new, params: { section_id: @section.id}
    assert_false assigns(:subview_optgroups).collect(&:name).include?("MembershipRequestView")
  end

  def test_available_abstract_views_for_no_connectionview_in_ongoing_mentoring_disabled_program
    custom_login
    programs(:albers).update_attribute :engagement_type, Program::EngagementType::CAREER_BASED
    get :new, params: { section_id: @section.id}
    assert_false assigns(:subview_optgroups).collect(&:name).include?("ConnectionView")
  end

  def test_new_for_no_engagement_section_in_ongoing_mentoring_disabled_program
    custom_login
    # changing engagement type of program to career based
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    
    get :new, params: { section_id: @section.id}
    assert_false (assigns(:sections).collect(&:default_section)).include?(Report::Section::DefaultSections::ENGAGEMENT)
  end

  private

  def custom_login(options = {})
    options.reverse_merge!({program: :albers, user: @report_manager, su_login: true})
    login_as_super_user if options[:su_login]
    current_program_is options[:program]
    current_user_is options[:user]
  end
end