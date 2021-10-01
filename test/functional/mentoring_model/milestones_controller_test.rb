require_relative './../../test_helper.rb'

class MentoringModel::MilestonesControllerTest < ActionController::TestCase
  def setup
    super
    @program = programs(:albers)
    @group = groups(:mygroup)
    programs(:org_primary).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    @group.allow_manage_mm_milestones!(@program.roles.for_mentoring_models)
  end

  def test_manage_mm_milestones_permission
    current_user_is :f_mentor
    @group.deny_manage_mm_milestones!(@program.roles.for_mentoring_models)

    assert_permission_denied do
      get :new, xhr: true, params: { group_id: @group.id}
    end
  end

  def test_permissions_from_template
    current_user_is :f_mentor
    milestone = create_mentoring_model_milestone(from_template: true)

    assert_permission_denied do
      get :edit, xhr: true, params: { id: milestone.id, group_id: @group.id}
    end
  end

  def test_new_success
    current_user_is :f_mentor

    get :new, xhr: true, params: { group_id: @group.id}
    assert_response :success

    assert assigns(:milestone).new_record?
  end

  def test_create_success
    current_user_is :f_mentor

    Group.any_instance.stubs(:get_position_for_new_milestone).returns(10)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_MILESTONE).once
    post :create, xhr: true, params: { group_id: @group.id, mentoring_model_milestone: {title: "Carrie Mathison"}}
    assert_response :success

    assert "Carrie Mathison", assigns(:milestone).title
    assert_false assigns(:milestone).from_template
    assert_nil assigns(:milestone).mentoring_model_milestone_template
    assert_equal 10, assigns(:milestone).position
  end

  def test_create_with_multiline_description
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    current_user_is users(:f_mentor)
    group = groups(:mygroup)
    program = group.program
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    group.allow_manage_mm_milestones!(program.roles.for_mentoring_models)

    milestone1 = create_mentoring_model_milestone(:description => "Test\n Description")
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_MILESTONE).once
    put :create, xhr: true, params: { id: milestone1.id, group_id: group.id, mentoring_model_milestone: {title: "Carrie Mathison", :description => "Test\n Description"}}
    assert_match /Test.*br.*Description/, response.body
  end

  def test_update
    current_user_is :f_mentor
    milestone = create_mentoring_model_milestone(title: "awesome")
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_MILESTONE).once
    put :create, xhr: true, params: { id: milestone.id, group_id: @group.id, mentoring_model_milestone: {title: "Carrie Mathison"}}
    assert_response :success

    assert "Carrie Mathison", assigns(:milestone).title
    assert_false assigns(:milestone).from_template
    assert_nil assigns(:milestone).mentoring_model_milestone_template
  end

  def test_destroy
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    current_user_is :f_mentor
    milestone = create_mentoring_model_milestone(title: "awesome")
    milestone1 = create_mentoring_model_milestone(title: "awesome")
    task1 = create_mentoring_model_task(milestone_id: milestone1.id)

    delete :destroy, xhr: true, params: { id: milestone.id, group_id: @group.id}
    assert_response :success
  end

  def test_fetch_tasks_for_milestone
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    current_user_is users(:f_mentor)
    group = groups(:mygroup)
    program = group.program
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    group.allow_manage_mm_milestones!(program.roles.for_mentoring_models)

    Timecop.freeze do
      current_date = Time.now.utc.to_date
      milestone1 = create_mentoring_model_milestone
      task1 = create_mentoring_model_task(milestone_id: milestone1.id, required: true, due_date: current_date + 5.days)
      task2 = create_mentoring_model_task(milestone_id: milestone1.id, required: true, due_date: current_date + 10.days)

      get :fetch_tasks, xhr: true, params: { group_id: group.id, id: milestone1.id, target_user_id: users(:f_mentor).id, target_user_type: GroupsController::TargetUserType::INDIVIDUAL, milestone_link_id: "#dummy_link"}
      assert_response :success
      assert_equal true, assigns(:surveys_controls_allowed)
      assert_equal({milestone1.id => [task1, task2]}, assigns(:mentoring_model_tasks))
      assert_equal "#dummy_link", assigns(:milestone_link_id)
      assert_equal users(:f_mentor), assigns(:target_user)
      assert_equal GroupsController::TargetUserType::INDIVIDUAL, assigns(:target_user_type)
      assert_false assigns(:home_page_view)

      get :fetch_tasks, xhr: true, params: { group_id: group.id, id: milestone1.id, target_user_id: users(:f_mentor).id, target_user_type: GroupsController::TargetUserType::INDIVIDUAL, milestone_link_id: "#dummy_link", home_page_view: true}
      assert_response :success
      assert_equal true, assigns(:surveys_controls_allowed)
      assert_equal({milestone1.id => [task1, task2]}, assigns(:mentoring_model_tasks))
      assert_equal "#dummy_link", assigns(:milestone_link_id)
      assert_equal users(:f_mentor), assigns(:target_user)
      assert_equal GroupsController::TargetUserType::INDIVIDUAL, assigns(:target_user_type)
      assert assigns(:home_page_view)

      task2.update_column(:due_date, current_date - 15.days)
      get :fetch_tasks, xhr: true, params: { group_id: group.id, id: milestone1.id, target_user_id: users(:f_mentor).id, target_user_type: GroupsController::TargetUserType::INDIVIDUAL, milestone_link_id: "#dummy_link", home_page_view: true}
      assert_response :success
      assert_equal true, assigns(:surveys_controls_allowed)
      assert_equal({milestone1.id => [task1]}, assigns(:mentoring_model_tasks))

      task1.update_column(:due_date, current_date - 15.days)
      get :fetch_tasks, xhr: true, params: { group_id: group.id, id: milestone1.id, target_user_id: users(:f_mentor).id, target_user_type: GroupsController::TargetUserType::INDIVIDUAL, milestone_link_id: "#dummy_link", home_page_view: true}
      assert_response :success
      assert_equal true, assigns(:surveys_controls_allowed)
      assert_equal({milestone1.id => [task1, task2]}, assigns(:mentoring_model_tasks))
    end
  end

  def test_fetch_tasks_for_milestone_with_meeting
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    current_user_is users(:f_mentor)
    group = groups(:mygroup)
    program = group.program
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    group.allow_manage_mm_milestones!(program.roles.for_mentoring_models)

    milestone1 = create_mentoring_model_milestone
    milestone2 = create_mentoring_model_milestone
    task1 = create_mentoring_model_task(milestone_id: milestone1.id, required: true, due_date: group.meetings.first.occurrences.first.start_time - 1.day)
    task2 = create_mentoring_model_task(milestone_id: milestone2.id, required: true, due_date: group.meetings.first.occurrences.first.start_time + 1.day)

    get :fetch_tasks, xhr: true, params: { group_id: group.id, id: milestone1.id, target_user_id: users(:f_mentor).id, target_user_type: GroupsController::TargetUserType::INDIVIDUAL, milestone_link_id: "#dummy_link"}
    assert_response :success
    assert_equal milestone1.id, assigns(:mentoring_model_tasks)[milestone1.id][0].milestone_id
  end

  def test_fetch_tasks_with_milestone_meeting_after_milestone_is_destroyed
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    current_user_is users(:f_mentor)
    group = groups(:mygroup)
    program = group.program
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    group.allow_manage_mm_milestones!(program.roles.for_mentoring_models)

    milestone1 = create_mentoring_model_milestone
    milestone2 = create_mentoring_model_milestone
    task1 = create_mentoring_model_task(milestone_id: milestone1.id, required: true, due_date: group.meetings.first.occurrences.first.start_time - 1.day)
    task2 = create_mentoring_model_task(milestone_id: milestone2.id, required: true, due_date: group.meetings.first.occurrences.first.start_time + 1.day)
    milestone1.destroy

    get :fetch_tasks, xhr: true, params: { group_id: group.id, id: milestone2.id, target_user_id: users(:f_mentor).id, target_user_type: GroupsController::TargetUserType::INDIVIDUAL, milestone_link_id: "#dummy_link"}
    assert_response :success
    assert_equal milestone2.id, assigns(:mentoring_model_tasks)[milestone2.id][0].milestone_id
  end

  def test_fetch_tasks_for_milestone_by_admin
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    current_user_is users(:f_admin)
    group = groups(:mygroup)
    program = group.program
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    group.allow_manage_mm_milestones!(program.roles.for_mentoring_models)

    milestone1 = create_mentoring_model_milestone

    task1 = create_mentoring_model_task(milestone_id: milestone1.id)
    task2 = create_mentoring_model_task(milestone_id: milestone1.id, required: true, due_date: Date.today + 10.days)

    get :fetch_tasks, xhr: true, params: { group_id: group.id, id: milestone1.id, target_user_id: users(:f_mentor).id, target_user_type: GroupsController::TargetUserType::INDIVIDUAL, milestone_link_id: "#dummy_link"}
    assert_response :success
    assert_equal false, assigns(:surveys_controls_allowed)
    assert_equal({milestone1.id => [task1, task2]}, assigns(:mentoring_model_tasks))
    assert_equal "#dummy_link", assigns(:milestone_link_id)
    assert_equal users(:f_mentor), assigns(:target_user)
    assert_equal GroupsController::TargetUserType::INDIVIDUAL, assigns(:target_user_type)
  end

  def test_fetch_completed_milestones
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    current_user_is users(:f_mentor)
    group = groups(:mygroup)
    program = group.program
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    group.allow_manage_mm_milestones!(program.roles.for_mentoring_models)

    milestone1 = create_mentoring_model_milestone
    milestone2 = create_mentoring_model_milestone

    create_mentoring_model_task(milestone_id: milestone1.id, status: MentoringModel::Task::Status::DONE)
    create_mentoring_model_task(milestone_id: milestone1.id, required: false, due_date: Date.today + 10.days)
    create_mentoring_model_task(milestone_id: milestone2.id, required: true, due_date: 16.days.from_now.utc)

    get :fetch_completed_milestones, xhr: true, params: { group_id: group.id, target_user_id: users(:f_mentor).id, target_user_type: GroupsController::TargetUserType::INDIVIDUAL, completed_milestones_link_id: "#dummy_link", completed_mentoring_model_milestone_ids: [milestone1.id]}
    assert_response :success
    assert_equal [milestone1], assigns(:completed_mentoring_model_milestones)
    assert_equal [milestone1.id], assigns(:mentoring_model_milestone_ids_to_expand)
    assert_equal "#dummy_link", assigns(:completed_milestones_link_id)
    assert_equal users(:f_mentor), assigns(:target_user)
    assert_equal GroupsController::TargetUserType::INDIVIDUAL, assigns(:target_user_type)
  end

  def test_destroy_with_target_user
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    current_user_is :f_mentor
    milestone = create_mentoring_model_milestone(title: "awesome")
    milestone1 = create_mentoring_model_milestone(title: "awesome")
    task1 = create_mentoring_model_task(milestone_id: milestone1.id, user: @group.members.first)
    task2 = create_mentoring_model_task(milestone_id: milestone1.id, user: @group.members.reload.last)

    delete :destroy, xhr: true, params: { id: milestone.id, group_id: @group.id, target_user_id: @group.members.first, target_user_type: GroupsController::TargetUserType::INDIVIDUAL}
    assert_response :success
  end

  def test_new_for_program_with_disabled_ongoing_mentoring
    current_user_is :f_mentor

    #disabling ongoing mentoring
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_permission_denied do
      get :new, xhr: true, params: { group_id: @group.id}
    end
  end
end