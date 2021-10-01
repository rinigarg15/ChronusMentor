require_relative './../../test_helper.rb'

class MentoringModel::GoalTemplatesControllerTest < ActionController::TestCase

  def setup
    super
    current_user_is :f_admin
    programs(:albers).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    @mentoring_model = programs(:albers).default_mentoring_model
  end

  def test_render_partial_for_new_action
    get :new, xhr: true, params: { mentoring_model_id: @mentoring_model.id}
    assert_response :success
    assert_match /modal-body clearfix/, response.body
  end

  def test_permission_denied_for_new_action
    create_object_role_permission("manage_mm_goals", {action: 'deny'})
    assert_permission_denied do
      get :new, xhr: true, params: { mentoring_model_id: @mentoring_model.id}
    end
  end

  def test_create_action
    program = programs(:albers)
    assert_difference "MentoringModel::GoalTemplate.count", 1 do
      post :create, xhr: true, params: { mentoring_model_id: @mentoring_model.id, :mentoring_model_goal_template => {title: "Hello", description: "HelloDesc"}}
    end
    assert_response :success
  end

  def test_permission_denied_for_create_action
    program = programs(:albers)
    create_object_role_permission("manage_mm_goals", {action: 'deny'})
    assert_no_difference "MentoringModel::GoalTemplate.count" do
      assert_permission_denied do
        post :create, xhr: true, params: { mentoring_model_id: @mentoring_model.id, :mentoring_model_goal_template => {title: "Hello", description: "HelloDesc"}}
      end
    end
  end

  def test_create_from_program_goal_with_feature_and_progress_type_disabled
    program = programs(:albers)
    assert_difference "MentoringModel::GoalTemplate.count", 1 do
      post :create, xhr: true, params: { mentoring_model_id: @mentoring_model.id, :mentoring_model_goal_template => {title: "Hello", description: "HelloDesc"}}
    end
    assert_response :success
    assert_equal assigns(:new_goal_template).title, "Hello"
    assert_equal assigns(:new_goal_template).description, "HelloDesc"
  end

  def test_update_action_for_goal_template
    program = programs(:albers)
    goal_template = @mentoring_model.mentoring_model_goal_templates.create!(title: "Hello1", description: "Hello1Desc")
    task_template1 = create_mentoring_model_task_template({goal_template_id: goal_template.id})
    put :update, xhr: true, params: { mentoring_model_id: @mentoring_model.id, :mentoring_model_goal_template => {title: "Hello2", description: "Hello2Desc"}, id: goal_template.id}
    goal_template.reload
    assert_equal "Hello2", goal_template.title
    assert_equal "Hello2Desc", goal_template.description
    assert_equal "Hello2", task_template1.goal_template.title
    assert_equal "Hello2Desc", task_template1.goal_template.description
    assert_response :success
  end

  def test_permission_denied_for_update_action
    program = programs(:albers)
    goal_template = @mentoring_model.mentoring_model_goal_templates.create!(title: "Hello1", description: "Hello1Desc")
    create_object_role_permission("manage_mm_goals", {action: 'deny'})
    assert_permission_denied do
      put :update, xhr: true, params: { mentoring_model_id: @mentoring_model.id, :mentoring_model_goal_template => {title: "Hello", description: "HelloDesc"}, id: goal_template.id}
    end
  end

  def test_delete_action_for_goal_template
    program = programs(:albers)
    @mentoring_model.deny_manage_mm_milestones!(program.roles.with_name([RoleConstants::ADMIN_NAME]))
    goal_template = @mentoring_model.mentoring_model_goal_templates.create!(title: "Hello1", description: "Hello1Desc")
    goal_template_1 = @mentoring_model.mentoring_model_goal_templates.create!(title: "Hello1", description: "Hello1Desc")
    task_template1 = create_mentoring_model_task_template(goal_template_id: goal_template.id)
    task_template2 = create_mentoring_model_task_template()

    assert_difference "MentoringModel::TaskTemplate.count", -1 do
      assert_difference "MentoringModel::GoalTemplate.count", -1 do
        delete :destroy, xhr: true, params: { id: goal_template.id, mentoring_model_id: @mentoring_model.id}
      end
    end
    assert_response :success

    assert_equal 1, assigns(:goal_templates).size
    assert_equal 1, assigns(:task_templates).size
  end

  def test_destroy_action_with_milestones_enabled
    program = programs(:albers)
    @mentoring_model.allow_manage_mm_milestones!(program.roles.with_name([RoleConstants::ADMIN_NAME]))

    goal_template1 = create_mentoring_model_goal_template

    milestone_template1 = create_mentoring_model_milestone_template
    milestone_template2 = create_mentoring_model_milestone_template

    task1 = create_mentoring_model_task_template(goal_template_id: goal_template1.id, milestone_template_id: milestone_template1.id)
    task2 = create_mentoring_model_task_template(goal_template_id: goal_template1.id, milestone_template_id: milestone_template1.id)
    task3 = create_mentoring_model_task_template(goal_template_id: goal_template1.id, milestone_template_id: milestone_template2.id)
    task4 = create_mentoring_model_task_template(milestone_template_id: milestone_template2.id)


    assert_difference "MentoringModel::TaskTemplate.count", -3 do
      assert_difference "MentoringModel::GoalTemplate.count", -1 do
        delete :destroy, xhr: true, params: { id: goal_template1.id, mentoring_model_id: @mentoring_model.id}
      end
    end
    assert_response :success

    assert assigns(:task_templates).is_a?(Hash)
    assert_equal({milestone_template1.id => [], milestone_template2.id => [task4]}, assigns(:task_templates))
  end

  def test_permission_denied_for_destroy_action
    program = programs(:albers)
    goal_template = @mentoring_model.mentoring_model_goal_templates.create!(title: "Hello1", description: "Hello1Desc")
    create_object_role_permission("manage_mm_goals", {action: 'deny'})
    assert_permission_denied do
      delete :destroy, xhr: true, params: { id: goal_template.id, mentoring_model_id: @mentoring_model.id}
    end
  end

  def test_asc_order_of_goal_templates
    program = programs(:albers)
    gt1 = @mentoring_model.mentoring_model_goal_templates.create!(title: "Hello1", description: "Hello1Desc")
    gt2 = @mentoring_model.mentoring_model_goal_templates.create!(title: "Hello1", description: "Hello1Desc")
    gt3 = @mentoring_model.mentoring_model_goal_templates.create!(title: "Hello1", description: "Hello1Desc")

    delete :destroy, xhr: true, params: { id: gt1.id, mentoring_model_id: @mentoring_model.id}
    assert_response :success

    assert_equal [gt2, gt3], assigns(:goal_templates)
  end

  def test_new_for_program_with_disabled_ongoing_mentoring
    #disabling ongoing mentoring
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_permission_denied do
      get :new, xhr: true, params: { mentoring_model_id: @mentoring_model.id}
    end
  end
end
