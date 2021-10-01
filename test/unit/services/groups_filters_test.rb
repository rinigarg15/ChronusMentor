require_relative './../../test_helper.rb'


class GroupsFilterTest < ActionView::TestCase
  include GroupsFilters

  def test_handle_survey_task_status_filter
    program =  programs(:no_mentor_request_program)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, true)
    survey = surveys(:progress_report)
    group = groups(:no_mreq_group)
    mentoring_model = program.default_mentoring_model
    mentoring_model.update_attribute(:should_sync, true)
    group.update_attribute(:mentoring_model_id, mentoring_model.id)

    options = {:due_date => 2.weeks.ago, :created_at => "July 04, 2016", :action_item_type => MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, :required => true, :action_item_id => survey.id, :group_id => group.id,:user => users(:no_mreq_mentor), :group => groups(:no_mreq_group), :status => MentoringModel::Task::Status::DONE}

    task1 = create_mentoring_model_task(options)

    options.merge!({:status => MentoringModel::Task::Status::TODO})
    task2 = create_mentoring_model_task(options)

    search_filter = {:survey_status=>{:survey_id=>survey.id, :survey_task_status=>"0"}}

    @with_options = {}
    @current_program = program
    @my_filters = []
    group_ids = self.send(:handle_survey_task_status_filter, search_filter)
    assert_equal group_ids, [group.id]

    search_filter = {:survey_status=>{:survey_id=>survey.id, :survey_task_status=>"2"}}
    group_ids = self.send(:handle_survey_task_status_filter, search_filter)
    assert_equal group_ids, [group.id]

    options = {:created_at => "July 04, 2016", :action_item_type => MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, :action_item_id => survey.id, :group_id => group.id,:user => users(:no_mreq_mentor), :group => groups(:no_mreq_group)}
    task3 = create_mentoring_model_task(options)

    search_filter = {:survey_status=>{:survey_id=>survey.id, :survey_task_status=>"2"}}
    group_ids = self.send(:handle_survey_task_status_filter, search_filter)
    assert_equal group_ids, [group.id]

    search_filter = {:survey_status=>{:survey_id=>survey.id, :survey_task_status=>""}}
    group_ids = self.send(:handle_survey_task_status_filter, search_filter)
    assert_nil group_ids

    search_filter = {:survey_status=>{:survey_id=>"", :survey_task_status=>"1"}}
    group_ids = self.send(:handle_survey_task_status_filter, search_filter)
    assert_nil group_ids

    search_filter = {}
    group_ids = self.send(:handle_survey_task_status_filter, search_filter)
    assert_nil group_ids
  end

  def test_get_common_member_based_filter_base
    program = programs(:albers)
    @with_options = {id: (1..10).to_a}
    @current_program = program
    mentor_role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    assert_equal [(1..10).to_a, program.connection_memberships.where(group_id: (1..10).to_a), {mentor_role.id => mentor_role.customized_term.term}, program.users.pluck(:id)], get_common_member_based_filter_base({mentor_role.id => []})
  end

  def test_set_member_profile_filters
    mentor_role = programs(:albers).roles.find_by(name: RoleConstants::MENTOR_NAME)
    stubs(:group_params).returns({member_profile_filters: {mentor_role.id => [{field: 'column9', operator: SurveyResponsesDataService::Operators::FILLED, value: ''}, {field: 'column10', operator: SurveyResponsesDataService::Operators::CONTAINS, value: ''}, {field: 'column11', operator: SurveyResponsesDataService::Operators::CONTAINS, value: 'abc'}]}})
    set_member_profile_filters
    assert_equal_hash({mentor_role.id => [{field: "column9", operator: SurveyResponsesDataService::Operators::FILLED, value: ""}, {field: "column11", operator: SurveyResponsesDataService::Operators::CONTAINS, value: "abc"}]}, @member_profile_filters)
  end

  def test_get_filtered_subset_of_group_ids
    program = programs(:albers)
    @with_options = {id: (1..10).to_a}
    @current_program = program
    mentor_role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    _group_ids, membership_scope, _role_term, _user_ids = get_common_member_based_filter_base({mentor_role.id => []})
    assert_equal [1], get_filtered_subset_of_group_ids(membership_scope, mentor_role.id, (1..3).to_a, {})
    assert_equal [1,9,10], get_filtered_subset_of_group_ids(membership_scope, mentor_role.id, (1..10).to_a, {removed_user_or_member_ids: []})
    assert_equal [1], get_filtered_subset_of_group_ids(membership_scope, mentor_role.id, (1..10).to_a, {removed_user_or_member_ids: [8]})
  end

  def test_handle_member_profile_based_filter
    program = programs(:albers)
    @current_program = program
    mentor_role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    profile_question = ProfileQuestion.find_by(question_text: "Ethnicity")

    choice = profile_question.question_choices.find_by(text: "Asian Indian")

    profile_answer = ProfileAnswer.new({profile_question_id: profile_question.id, answer_text: "Asian Indian", ref_obj: Group.find(10).mentors[0].member})
    profile_answer.answer_value = "Asian Indian"
    profile_answer.save

    profile_answer1 = ProfileAnswer.new({profile_question_id: profile_question.id, answer_text: "Japanese", ref_obj: Group.find(5).mentors[0].member})
    profile_answer1.answer_value = "Japanese"
    profile_answer1.save

    hsh = HashWithIndifferentAccess.new({member_profile_filters: {mentor_role.id => [HashWithIndifferentAccess.new({field: "column#{profile_question.id}", operator: SurveyResponsesDataService::Operators::NOT_FILLED, value: choice.id})]}})

    @with_options = {id: (1..100).to_a}
    @my_filters = []
    hsh[:member_profile_filters][mentor_role.id][0][:operator] = SurveyResponsesDataService::Operators::CONTAINS
    stubs(:group_params).returns(hsh)
    handle_member_profile_based_filter
    assert_equal [{label: "Mentor profile fields", reset_suffix: "member_profile_filter_#{mentor_role.id}"}], @my_filters
    assert_equal_unordered [9, 10], @with_options[:id]

    @with_options = {id: (1..100).to_a}
    @my_filters = []
    hsh[:member_profile_filters][mentor_role.id][0][:operator] = SurveyResponsesDataService::Operators::NOT_CONTAINS
    stubs(:group_params).returns(hsh)
    handle_member_profile_based_filter
    assert_equal [{label: "Mentor profile fields", reset_suffix: "member_profile_filter_#{mentor_role.id}"}], @my_filters
    assert_equal_unordered [1, 2, 3, 4, 5, 6, 11, 12], @with_options[:id]

    @with_options = {id: (1..100).to_a}
    @my_filters = []
    hsh[:member_profile_filters][mentor_role.id][0][:operator] = SurveyResponsesDataService::Operators::FILLED
    stubs(:group_params).returns(hsh)
    handle_member_profile_based_filter
    assert_equal [{label: "Mentor profile fields", reset_suffix: "member_profile_filter_#{mentor_role.id}"}], @my_filters
    assert_equal_unordered [9, 10, 5, 6, 11, 12], @with_options[:id]

    @with_options = {id: (1..100).to_a}
    @my_filters = []
    hsh[:member_profile_filters][mentor_role.id][0][:operator] = SurveyResponsesDataService::Operators::NOT_FILLED
    stubs(:group_params).returns(hsh)
    handle_member_profile_based_filter
    assert_equal [{label: "Mentor profile fields", reset_suffix: "member_profile_filter_#{mentor_role.id}"}], @my_filters
    assert_equal_unordered [1, 2, 3, 4], @with_options[:id]
  end

  def test_apply_survey_task_status_filter
    program =  programs(:no_mentor_request_program)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, true)
    survey = surveys(:progress_report)
    group = groups(:no_mreq_group)
    mentoring_model = program.default_mentoring_model
    mentoring_model.update_attribute(:should_sync, true)
    group.update_attribute(:mentoring_model_id, mentoring_model.id)

    options = {:due_date => 2.weeks.ago, :created_at => "July 04, 2016", :action_item_type => MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, :required => true, :action_item_id => survey.id, :group_id => group.id,:user => users(:no_mreq_mentor), :group => groups(:no_mreq_group), :status => MentoringModel::Task::Status::DONE}

    task1 = create_mentoring_model_task(options)

    options.merge!({:status => MentoringModel::Task::Status::TODO})
    task2 = create_mentoring_model_task(options)

    @current_program = program
    @my_filters = []

    survey_filter = {:survey_id=>survey.id, :survey_task_status=>"0"}
    group_ids = self.send(:apply_survey_task_status_filter, survey_filter, {})
    assert_equal group_ids, [group.id]

    survey_filter = {:survey_id=>survey.id, :survey_task_status=>"2"}
    group_ids = self.send(:apply_survey_task_status_filter, survey_filter, {})
    assert_equal group_ids, [group.id]

    options = {:created_at => "July 04, 2016", :action_item_type => MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, :action_item_id => survey.id, :group_id => group.id,:user => users(:no_mreq_mentor), :group => groups(:no_mreq_group)}
    task3 = create_mentoring_model_task(options)
    survey_filter = {:survey_id=>survey.id, :survey_task_status=>"1"}
    group_ids = self.send(:apply_survey_task_status_filter, survey_filter, {})
    assert_equal group_ids, [group.id]
  end

  def test_construct_group_search_options
    program =  programs(:no_mentor_request_program)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, true)
    survey = surveys(:progress_report)
    group_params = {:search_filters =>{:survey_status=>{:survey_id=>survey.id, :survey_task_status=>"0"}, :survey_response=>{:survey_id=>""}, :profile_name=>"", :started_date=>"", :expiry_date =>""}}
    @with_options = {}
    @current_program = program
    @my_filters = []
    @is_manage_connections_view = true
    @mentoring_model_v2_enabled = true
    @tab_number = 0
    
    self.stubs(:group_params).returns(group_params)
    self.stubs(:sub_program_search_options).returns({:rubbish => true
      })
    self.expects(:handle_survey_response_filter).with(group_params[:search_filters]).at_least(1)
    self.expects(:handle_survey_task_status_filter).with(group_params[:search_filters]).at_least(1)
    construct_group_search_options

    @tab_number = nil
    self.expects(:handle_survey_response_filter).with(group_params[:search_filters]).at_least(1)
    self.expects(:handle_survey_task_status_filter).with(group_params[:search_filters]).at_least(1)
    construct_group_search_options

    @tab_number = 1
    self.expects(:handle_survey_response_filter).with(group_params[:search_filters]).never
    self.expects(:handle_survey_task_status_filter).with(group_params[:search_filters]).never
    construct_group_search_options
  end

  def test_handle_dashboard_health_filters
    @groups_scope = Group.where(id: [1,2,3,4])
    @with_options = {}
    self.stubs(:get_group_id_based_on_dashboard_filters).with("type", "start_date", "end_date").returns([])
    assert_equal 0, handle_dashboard_health_filters({type: "type", start_date: "start_date", end_date: "end_date"})
    assert_equal [0], @with_options[:id]

    @with_options[:id] = nil
    self.stubs(:get_group_id_based_on_dashboard_filters).with("type", "start_date", "end_date").returns([1,2,5])
    assert_equal 3, handle_dashboard_health_filters({type: "type", start_date: "start_date", end_date: "end_date"})
    assert_equal [1,2], @with_options[:id]

    @with_options[:id] = [3,4,5]
    assert_equal 3, handle_dashboard_health_filters({type: "type", start_date: "start_date", end_date: "end_date"})
    assert_equal [5], @with_options[:id]
  end

  def test_get_group_id_based_on_dashboard_filters
    @current_program = programs(:albers)
    start_date = "2017-09-05"
    end_date = "2018-01-15"

    date_range = start_date.to_date.beginning_of_day.in_time_zone(Time.zone)..end_date.to_date.end_of_day.in_time_zone(Time.zone)
    @current_program.stubs(:get_group_data_for_positive_outcome_between).with(date_range).returns("good")
    @current_program.stubs(:get_group_data_for_neutral_outcome_between).with(date_range).returns("bad")
    @current_program.stubs(:groups_with_overdue_survey_responses_and_active_within).with(date_range).returns("ugly")

    assert_equal "good", get_group_id_based_on_dashboard_filters(GroupsController::DashboardFilter::GOOD, start_date, end_date)
    assert_equal "bad", get_group_id_based_on_dashboard_filters(GroupsController::DashboardFilter::NEUTRAL_BAD, start_date, end_date)
    assert_equal "ugly", get_group_id_based_on_dashboard_filters(GroupsController::DashboardFilter::NO_RESPONSE, start_date, end_date)
  end

  private

  def current_program
    @current_program
  end
end