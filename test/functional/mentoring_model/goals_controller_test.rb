require_relative './../../test_helper.rb'

class MentoringModel::GoalsControllerTest < ActionController::TestCase

  def setup
    super
    @group = groups(:mygroup)
    @student = @group.students.first
    @mentor = @group.mentors.first
    programs(:albers).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
  end

  def test_fetch_goals_for_destroy_action
    create_object_role_permission("manage_mm_goals", role: "users", object: @group)
    mmg1 = create_mentoring_model_goal
    mmg2 = create_mentoring_model_goal
    mmg3 = create_mentoring_model_goal

    current_user_is @mentor
    delete :destroy, xhr: true, params: { :group_id => @group.id, :id => mmg1.id}
    assert_response :success

    assert_equal mmg1, assigns(:goal)
    assert_equal [mmg2, mmg3], assigns(:goals)
    assert assigns(:edit_goal_plan)
  end

  def test_fetch_goal_for_update_action
    create_object_role_permission("manage_mm_goals", role: "users", object: @group)
    mmg1 = create_mentoring_model_goal

    current_user_is @mentor
    put :update, xhr: true, params: { :group_id => @group.id, :id => mmg1.id, :mentoring_model_goal => {:title => "My Updated Title"}}
    assert_response :success

    assert_equal mmg1, assigns(:goal)
    assert_equal "My Updated Title", assigns(:goal).title
    assert assigns(:edit_goal_plan)
    assert_nil assigns(:goal).mentoring_model_goal_template
  end

  def test_render_partial_for_new_action
    create_object_role_permission("manage_mm_goals", role: "users", object: @group)
    current_user_is @mentor
    get :new, xhr: true, params: { :group_id => @group.id}
    assert_response :success
    assert_match /modal-body clearfix/, response.body
    assert assigns(:edit_goal_plan)
  end

  def test_create_mentoring_model_goal
    create_object_role_permission("manage_mm_goals", role: "users", object: @group)
    current_user_is @mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_GOAL).once
    post :create, xhr: true, params: { :group_id => @group.id, :mentoring_model_goal => {:title => "My New Goal", :description => "My New Desc"}}
    assert_response :success

    assert_equal "My New Goal", assigns(:new_goal).title
    assert_equal "My New Desc", assigns(:new_goal).description
    assert assigns(:edit_goal_plan)
    assert_nil assigns(:skip_mentoring_model_goals_side_pane)
    assert_nil assigns(:new_goal).mentoring_model_goal_template
  end

  def test_index_action_for_mentoring_model_goal
    create_object_role_permission("manage_mm_goals", role: "users", object: @group)
    mmg1 = create_mentoring_model_goal
    mmg2 = create_mentoring_model_goal
    mmg3 = create_mentoring_model_goal

    current_user_is @mentor
    get :index, params: { :group_id => @group.id}
    assert_response :success

    assert_equal [mmg1, mmg2, mmg3], assigns(:goals)
    assert assigns(:skip_mentoring_model_goals_side_pane)
    assert assigns(:edit_goal_plan)
  end

  def test_index_action_for_update_action_for_mentee
    create_object_role_permission("manage_mm_goals", role: "users", object: @group)
    mmg1 = create_mentoring_model_goal
    mmg2 = create_mentoring_model_goal
    mmg3 = create_mentoring_model_goal

    current_user_is @student
    get :index, params: { :group_id => @group.id}
    assert_response :success

    assert_false response.body.match /Update/
  end

  def test_index_action_for_mentoring_model_manual_progress_goal
    create_object_role_permission("manage_mm_goals", role: "users", object: @group)
    mmg1 = create_mentoring_model_goal
    mmg2 = create_mentoring_model_goal
    mentoring_model = @group.program.mentoring_models.first
    mentoring_model.update_attribute(:goal_progress_type, MentoringModel::GoalProgressType::MANUAL)
    goal_template = create_mentoring_model_goal_template(mentoring_model_id: mentoring_model.id)
    mmg1.update_attribute(:mentoring_model_goal_template, mentoring_model.mentoring_model_goal_templates.first)
    mmg2.update_attribute(:mentoring_model_goal_template, mentoring_model.mentoring_model_goal_templates.first)

    current_user_is @mentor
    get :index, params: { :group_id => @group.id}
    assert_response :success

    assert_select "div.cjs_display_all_goals" do
      assert_select "div.cjs_display_goal_and_task_block_#{mmg1.id}" do
        assert_select "div#manual_progress_goal_#{mmg1.id}"
        assert_select "div#cjs-goals-activity-container-#{mmg1.id}"
      end
      assert_select "div.cjs_display_goal_and_task_block_#{mmg2.id}" do
        assert_select "div#manual_progress_goal_#{mmg2.id}"
        assert_select "div#cjs-goals-activity-container-#{mmg2.id}"
      end
    end
  end

  def test_permission_denied_for_destroy_action
    mmg1 = create_mentoring_model_goal
    current_user_is @mentor
    assert_permission_denied {delete :destroy, xhr: true, params: { :group_id => @group.id, :id => mmg1.id}}
    assert_false assigns(:edit_goal_plan)
  end

  def test_denied_action_for_update_action
    mmg1 = create_mentoring_model_goal
    current_user_is @mentor
    assert_permission_denied {put :update, xhr: true, params: { :group_id => @group.id, :id => mmg1.id, :mentoring_model_goal => {:title => "My Updated Title"} }}
    assert_not_equal "My Updated Title", mmg1.title
    assert_false assigns(:edit_goal_plan)
  end

  def test_permission_denied_for_new_action
    current_user_is @mentor
    assert_permission_denied do
      get :new, xhr: true, params: { :group_id => @group.id}
    end
    assert_false assigns(:edit_goal_plan)
  end

  def test_permission_denied_when_feature_disabled
    mentoring_model_goal = create_mentoring_model_goal
    programs(:albers).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, false)
    current_user_is @mentor
    assert_permission_denied { get :index, xhr: true, params: { :group_id => @group.id}}
    assert_false assigns(:edit_goal_plan)
  end

  def test_permission_denied_for_create_mentoring_model_goal
    current_user_is @mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_GOAL).never
    assert_permission_denied { post :create, xhr: true, params: { :group_id => @group.id, :mentoring_model_goal => {:title => "My New Goal", :description => "My New Desc"}}}
    assert_false assigns(:edit_goal_plan)
  end

  def test_restrict_altering_of_goals_from_template_for_update
    current_user_is @mentor
    @goal = create_mentoring_model_goal
    @goal.update_attribute(:from_template, true)
    assert_permission_denied do
      put :update, xhr: true, params: { group_id: @group.id, id: @goal.id, mentoring_model_goal: {
        title: "changed title", description: "changed description"
      }}
    end
  end

  def test_restrict_altering_of_goals_from_template_for_destroy
    current_user_is @mentor
    @goal = create_mentoring_model_goal
    @goal.update_attribute(:from_template, true)
    assert_permission_denied do
      delete :destroy, xhr: true, params: { group_id: @group.id, id: @goal.id}
    end
  end

  def test_edit_goal_plan_for_admin_role
    current_user_is :f_admin
    programs(:albers).confidentiality_audit_logs.create!(:user_id => users(:f_admin).id, :reason =>"This is another reason", :group_id => @group.id)

    get :index, params: { :group_id => @group.id}
    assert_response :success

    assert_false assigns(:page_controls_allowed)
    assert_false assigns(:edit_goal_plan)
  end

  def test_new_for_program_with_disabled_ongoing_mentoring
    #disabling ongoing mentoring
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    create_object_role_permission("manage_mm_goals", role: "users", object: @group)
    current_user_is @mentor
    assert_permission_denied do
      get :new, xhr: true, params: { :group_id => @group.id}
    end
  end

end
