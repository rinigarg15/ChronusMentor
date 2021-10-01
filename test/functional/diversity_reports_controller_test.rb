require_relative './../test_helper.rb'

class DiversityReportsControllerTest < ActionController::TestCase
  def setup
    return_value = super
    @organization = programs(:org_primary)
    @view = @organization.admin_views.find_by(default_view: AbstractView::DefaultType::ALL_MEMBERS)
    @profile_question = @organization.profile_questions.select(&:with_question_choices?).first
    @diversity_report = @organization.diversity_reports.create!({admin_view: @view, profile_question: @profile_question, comparison_type: DiversityReport::ComparisonType::TIME_PERIOD})
    current_organization_is @organization
    current_member_is :f_admin
    @controller.stubs(:can_access_global_reports?).returns(true)
    return_value
  end

  def test_show
    cuurent_date = @organization.created_at + 10.days
    Timecop.freeze(cuurent_date) do
      get :show, xhr: true, params: {id: @diversity_report.id}
      assert_response :success
      assert_equal @organization.created_at.to_date, assigns(:start_date)
      assert_equal cuurent_date.to_date, assigns(:end_date)
    end
  end

  def test_show_within_time_period
    Timecop.freeze do
      get :show, xhr: true, params: {id: @diversity_report.id, date_range: "09/10/2018 - 09/20/2018"}
      assert_response :success
      assert_equal Date.new(2018, 9, 10), assigns(:start_date)
      assert_equal Date.new(2018, 9, 20), assigns(:end_date)
    end
  end

  def test_new
    get :new, xhr: true
    assert_response :success
    assert_equal @organization, @diversity_report.organization
  end

  def test_create
    assert_difference 'DiversityReport.count', 1 do
      post :create, xhr: true, params: {diversity_report: {admin_view_id: @view.id, profile_question_id: @profile_question.id, comparison_type: DiversityReport::ComparisonType::PARTICIPANT, name: "Report Name"}}
      assert_response :success
      diversity_report = DiversityReport.last
      assert_equal @organization, diversity_report.organization
      assert_equal @view, diversity_report.admin_view
      assert_equal @profile_question, diversity_report.profile_question
      assert_equal DiversityReport::ComparisonType::PARTICIPANT, diversity_report.comparison_type
      assert_equal "Report Name", diversity_report.name
    end
  end

  def test_edit
    get :edit, xhr: true, params: {id: @diversity_report.id}
    assert_response :success
    assert_equal @diversity_report, assigns(:diversity_report)
  end

  def test_update
    assert_no_difference 'DiversityReport.count' do
      view = @organization.admin_views.find_by(default_view: AbstractView::DefaultType::LICENSE_COUNT)
      profile_question = @organization.profile_questions.select(&:with_question_choices?).last
      put :update, xhr: true, params: {id: @diversity_report.id, diversity_report: {admin_view_id: view.id, profile_question_id: profile_question.id, comparison_type: DiversityReport::ComparisonType::TIME_PERIOD, name: "Updated Report Name"}}
      assert_response :success
      @diversity_report.reload
      assert_equal @diversity_report, assigns(:diversity_report)
      assert_equal @organization, @diversity_report.organization
      assert_equal view, @diversity_report.admin_view
      assert_equal profile_question, @diversity_report.profile_question
      assert_equal DiversityReport::ComparisonType::TIME_PERIOD, @diversity_report.comparison_type
      assert_equal "Updated Report Name", @diversity_report.name
    end
  end

  def test_destroy
    assert_difference 'DiversityReport.count', -1 do
      post :destroy, xhr: true, params: {id: @diversity_report.id}
      assert_equal @diversity_report, assigns(:diversity_report)
      assert_response :success
    end
  end
end