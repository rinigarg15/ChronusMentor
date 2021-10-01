require_relative './../test_helper.rb'

class GlobalReportsControllerTest < ActionController::TestCase

  def setup
    super
    current_member_is :f_admin
    @controller.stubs(:can_access_global_reports?).returns(true)
  end

  def test_access_denied
    @controller.stubs(:can_access_global_reports?).returns(false)
    assert_permission_denied do
      get :index
    end
  end

  def test_index
    current_date = Date.current
    Timecop.freeze(current_date)
    organization = programs(:org_primary)
    current_organization_is organization
    
    get :index, params: {}
    assert_response :success
    assert_equal_hash ({from: organization.created_at.beginning_of_day, to: current_date.end_of_day}), assigns(:overall_impact_date_range)
    assert_equal assigns(:diversity_reports), programs(:org_primary).diversity_reports
  end

  # no date filter, wihtout overall_impact_hash
  def test_overall_impact_p1
    current_date = Date.current
    Timecop.freeze(current_date)
    organization = programs(:org_primary)
    current_organization_is organization

    get :overall_impact, xhr: true, params: {}
    assert_response :success
    assert_equal_hash ({from: organization.created_at.beginning_of_day, to: current_date.end_of_day}), assigns(:overall_impact_date_range)
    assert_equal ({}), assigns(:filters)
    assert_nil assigns(:overall_impact_hash)

    get :overall_impact, xhr: true, params: {users_participated: true, connections_created: true, engagements_created: true, satisfaction_rate: true}
    assert_response :success
    assert_equal_unordered [:users_participated, :connections_created, :engagements_created, :positive_outcomes_not_configured, :date_range_hash], assigns(:overall_impact_hash).keys
  end

  # no date filter, all overall_impact keys, org_created_time to ytd
  def test_overall_impact_p2
    organization = programs(:org_primary)
    current_organization_is organization
    current_date = organization.members.first.created_at + 3.days
    Timecop.freeze(current_date)

    get :overall_impact, xhr: true, params: {users_participated: true, connections_created: true, engagements_created: true, satisfaction_rate: true}
    assert_response :success
    assert_equal_hash ({from: organization.created_at.beginning_of_day, to: current_date.end_of_day}), assigns(:overall_impact_date_range)
    assert_equal ({}), assigns(:filters)
    assert_equal_unordered [:users_participated, :connections_created, :engagements_created, :date_range_hash, :positive_outcomes_not_configured], assigns(:overall_impact_hash).keys
    assert_equal_hash ({current: 51}), assigns(:overall_impact_hash)[:users_participated]
    assert_equal_hash ({current: 14}), assigns(:overall_impact_hash)[:connections_created]
    assert_equal_unordered [:messages, :meetings, :posts], assigns(:overall_impact_hash)[:engagements_created].keys
    assert_equal_hash ({current: 12}), assigns(:overall_impact_hash)[:engagements_created][:messages]
    assert_equal 15, assigns(:overall_impact_hash)[:engagements_created][:meetings][:current].size
    assert_nil assigns(:overall_impact_hash)[:engagements_created][:meetings][:previous]
    assert_equal_hash ({current: 0}), assigns(:overall_impact_hash)[:engagements_created][:posts]
    assert_nil assigns(:overall_impact_hash)[:satisfaction_rate]
  end

  # all overall_impact keys, with date filter
  def test_overall_impact_p3
    organization = programs(:org_primary)
    current_organization_is organization
    from_date = organization.members.first.created_at + 3.days
    to_date = from_date + 1.day
    date_range = "#{from_date.strftime('%m/%d/%Y')} - #{to_date.strftime('%m/%d/%Y')}"
    Timecop.freeze(from_date)

    get :overall_impact, xhr: true, params: {users_participated: true, connections_created: true, engagements_created: true, satisfaction_rate: true, filters: {date_range: date_range}}
    assert_response :success
    assert_equal_hash ({from: from_date.beginning_of_day, to: to_date.end_of_day}), assigns(:overall_impact_date_range)
    assert_equal_hash ({date_range: date_range}), assigns(:filters)
    assert_equal_unordered [:users_participated, :connections_created, :engagements_created, :date_range_hash, :positive_outcomes_not_configured], assigns(:overall_impact_hash).keys
    assert_equal_hash ({current: 51, previous: 51}), assigns(:overall_impact_hash)[:users_participated]
    assert_equal_hash ({current: 9, previous: 10}), assigns(:overall_impact_hash)[:connections_created]
    assert_equal_unordered [:messages, :meetings, :posts], assigns(:overall_impact_hash)[:engagements_created].keys
    assert_equal_hash ({current: 0, previous: 0}), assigns(:overall_impact_hash)[:engagements_created][:messages]
    assert_equal 2, assigns(:overall_impact_hash)[:engagements_created][:meetings][:current].size
    assert_equal 3, assigns(:overall_impact_hash)[:engagements_created][:meetings][:previous].size
    assert_equal_hash ({current: 0, previous: 0}), assigns(:overall_impact_hash)[:engagements_created][:posts]
    assert_nil assigns(:overall_impact_hash)[:satisfaction_rate]
  end

  # with survey satisfaction configurations
  def test_overall_impact_p4
    organization = programs(:org_primary)
    current_organization_is organization
    current_date = organization.members.first.created_at + 3.days
    @controller.stubs(:positive_outcome_surveys_by_program).returns({32 => {surveys: ["first survey"]}})
    Timecop.freeze(current_date)
    
    get :overall_impact, xhr: true, params: {satisfaction_rate: true}
    assert_response :success
    assert_equal_hash ({from: organization.created_at.beginning_of_day, to: current_date.end_of_day}), assigns(:overall_impact_date_range)
    assert_equal ({}), assigns(:filters)
    assert_equal_unordered [:date_range_hash, :positive_outcomes_not_configured, :satisfaction_rate], assigns(:overall_impact_hash).keys
    assert_false assigns(:overall_impact_hash)[:positive_outcomes_not_configured]
    assert_equal_hash ({current: 0}), assigns(:overall_impact_hash)[:satisfaction_rate]
  end

  def test_overall_impact_survey_satisfaction_configurations
    organization = programs(:org_primary)
    current_organization_is organization

    get :overall_impact_survey_satisfaction_configurations, xhr: true
    assert_equal_unordered [{program_name: "Albers Mentor Program", surveys: [], config: nil, program_outcomes_feature_enabled: false}, {program_name: "NWEN", surveys: [], config: nil, program_outcomes_feature_enabled: false}, {program_name: "Moderated Program", surveys: [], config: nil, program_outcomes_feature_enabled: false}, {program_name: "No Mentor Request Program", surveys: [], config: nil, program_outcomes_feature_enabled: false}, {program_name: "Project Based Engagement", surveys: [], config: nil, program_outcomes_feature_enabled: false}], assigns(:positive_outcome_surveys_by_program).values
  end

  def test_edit_overall_impact_survey_satisfaction_configuration
    organization = programs(:org_primary)
    current_organization_is organization
    program = organization.programs.first

    get :edit_overall_impact_survey_satisfaction_configuration, xhr: true, params: {program_id: program.id}
    assert_equal program, assigns(:survey_satisfaction_program)
  end

  # neither ignore nor reconsider
  def test_update_overall_impact_survey_satisfaction_configuration_p1
    organization = programs(:org_primary)
    current_organization_is organization

    program = organization.programs.first
    Program.any_instance.stubs(:program_outcomes_report_enabled?).returns(true)

    patch :update_overall_impact_survey_satisfaction_configuration, xhr: true, params: {program_id: program.id}
    assert_equal program, assigns(:survey_satisfaction_program)
    assert_nil assigns(:survey_satisfaction_program).include_surveys_for_satisfaction_rate
    assert_equal_hash ({program_name: program.name, surveys: program.get_positive_outcome_surveys, config: nil, program_outcomes_feature_enabled: true}), assigns(:survey_satisfaction_configuration_hash)
  end

  # ignore
  def test_update_overall_impact_survey_satisfaction_configuration_p2
    organization = programs(:org_primary)
    current_organization_is organization

    program = organization.programs.first  
    Program.any_instance.stubs(:program_outcomes_report_enabled?).returns(true)
    
    patch :update_overall_impact_survey_satisfaction_configuration, xhr: true, params: {program_id: program.id, ignore: true}
    assert_equal program, assigns(:survey_satisfaction_program)
    assert_false assigns(:survey_satisfaction_program).include_surveys_for_satisfaction_rate
    assert_equal_hash ({program_name: program.name, surveys: [], config: false, program_outcomes_feature_enabled: true}), assigns(:survey_satisfaction_configuration_hash)
  end

  # reconsider
  def test_update_overall_impact_survey_satisfaction_configuration_p3
    organization = programs(:org_primary)
    current_organization_is organization

    program = organization.programs.first  
    Program.any_instance.stubs(:program_outcomes_report_enabled?).returns(true)
    
    patch :update_overall_impact_survey_satisfaction_configuration, xhr: true, params: {program_id: program.id, reconsider: true}
    assert_equal program, assigns(:survey_satisfaction_program)
    assert assigns(:survey_satisfaction_program).include_surveys_for_satisfaction_rate
    assert_equal_hash ({program_name: program.name, surveys: program.get_positive_outcome_surveys, config: true, program_outcomes_feature_enabled: true}), assigns(:survey_satisfaction_configuration_hash)
  end

  # program_outcomes_report feature disabled
  def test_update_overall_impact_survey_satisfaction_configuration_p4
    organization = programs(:org_primary)
    current_organization_is organization

    program = organization.programs.first  
    Program.any_instance.stubs(:program_outcomes_report_enabled?).returns(false)
    
    patch :update_overall_impact_survey_satisfaction_configuration, xhr: true, params: {program_id: program.id}
    assert_equal program, assigns(:survey_satisfaction_program)
    assert_nil assigns(:survey_satisfaction_program).include_surveys_for_satisfaction_rate
    assert_equal_hash ({program_name: program.name, surveys: [], config: nil, program_outcomes_feature_enabled: false}), assigns(:survey_satisfaction_configuration_hash)
  end

  def test_safe_percentage
    assert_equal 200, GlobalReportsController.new.send(:safe_percentage, 6, 3)
    assert_equal 100, GlobalReportsController.new.send(:safe_percentage, 6, 0)
    assert_equal 0, GlobalReportsController.new.send(:safe_percentage, 0, 0)
  end
end