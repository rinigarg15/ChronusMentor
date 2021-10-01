require_relative './../../test_helper.rb'

class MentoringModel::TaskTemplatesControllerTest < ActionController::TestCase
  def setup
    super
    current_user_is :f_admin
    @program = programs(:albers)
    @program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    @admin_role = @program.get_role(RoleConstants::ADMIN_NAME)
    @mentoring_model = programs(:albers).default_mentoring_model
    @mentoring_model.deny_manage_mm_milestones!(@admin_role)
  end

  def test_new_action
    get :new, xhr: true, params: { mentoring_model_id: @mentoring_model.id}
    assert_response :success
    assert_template %r{mentoring_model/task_templates/_task_template_progressive_form}
    assert_not_nil assigns(:task_template)
    assert_equal 0, assigns(:goal_templates_to_associate).size
    assert_nil assigns(:milestone_templates_to_associate)
    assert_nil assigns(:milestone_template)
    assert_equal 7, assigns(:task_template).duration
    assert_equal MentoringModel::TaskTemplate::ActionItem::DEFAULT, assigns(:task_template).action_item_type
    assert_nil assigns(:action_items_to_associate)
  end

  def test_new_survey_task
    get :new, xhr: true, params: { mentoring_model_id: @mentoring_model.id, new_survey: "true"}
    assert_response :success
    assert_equal MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, assigns(:task_template).action_item_type
    assert_equal 5, assigns(:action_items_to_associate).count
  end

  def test_before_actions_should_not_execute_for_xhr
    ## Access from restricted ips
    configure_allowed_ips_to_restrict
    member = members(:f_admin)
    user = users(:f_admin)
    ## T & C not accepted
    member.update_attribute(:terms_and_conditions_accepted, nil)

    ## Profile Pending
    user.state = User::Status::PENDING
    user.save!

    ## No audit activity
    assert_no_difference "ActivityLog.count" do
      get :new, xhr: true, params: { mentoring_model_id: @mentoring_model.id}
    end
    assert_response :success
    assert_template %r{mentoring_model/task_templates/_task_template_progressive_form}

    ## No tab configurations
    assert_nil assigns(:no_tabs)
  end

  def test_create_action
    template_version_increases_by_one_and_triggers_sync_once "@mentoring_model" do
      assert_difference "MentoringModel::TaskTemplate.count", 1 do
        post :create, xhr: true, params: { mentoring_model_id: @mentoring_model.id, mentoring_model_task_template: {
          required: "false", title: "some title", description: "description", role_id: @program.roles.for_mentoring.last.id, duration: 1
        }}
      end
    end
    assert_response :success
    assert_equal "some title", assigns(:task_template).title
    assert_equal "description", assigns(:task_template).description
    assert_false assigns(:task_template).required?
    assert_equal @program.roles.for_mentoring.last, assigns(:task_template).role
  end

  def test_create_action_with_vulnerable_content_with_version_v1
    current_user_is :f_admin
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v1")
    assert_no_difference "VulnerableContentLog.count" do
      template_version_increases_by_one_and_triggers_sync_once "@mentoring_model" do
        assert_difference "MentoringModel::TaskTemplate.count", 1 do
          post :create, xhr: true, params: { mentoring_model_id: @mentoring_model.id, mentoring_model_task_template: {
            required: "false", title: "some title", description: "description<script>alert(10);</script>", role_id: @program.roles.for_mentoring.last.id, duration: 1
          }}
        end
      end
    end
  end

  def test_create_action_with_vulnerable_content_with_version_v2
    current_user_is :f_admin
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v2")
    template_version_increases_by_one_and_triggers_sync_once "@mentoring_model" do
      assert_difference "VulnerableContentLog.count" do
        assert_difference "MentoringModel::TaskTemplate.count", 1 do
          post :create, xhr: true, params: { mentoring_model_id: @mentoring_model.id, mentoring_model_task_template: {
            required: "false", title: "some title", description: "description<script>alert(10);</script>", role_id: @program.roles.for_mentoring.last.id, duration: 1
          }}
        end
      end
    end
  end

  def test_create_action_with_duration_id_input
    assert_difference "MentoringModel::TaskTemplate.count", 1 do
      post :create, xhr: true, params: { mentoring_model_id: @mentoring_model.id, duration_id_input: "7", mentoring_model_task_template: {
        required: "1", title: "some title", description: "description", role_id: @program.roles.for_mentoring.last.id, duration: 1,  date_assigner: MentoringModel::TaskTemplate::DueDateType::PREDECESSOR
      }}
    end
    assert_response :success
    assert_equal "some title", assigns(:task_template).title
    assert_equal "description", assigns(:task_template).description
    assert assigns(:task_template).required?
    assert_equal @program.roles.for_mentoring.last, assigns(:task_template).role
    assert_equal 7, assigns(:task_template).duration
    assert_nil assigns(:task_template).specific_date
  end

  def test_create_action_with_specific_date
    assert_difference "MentoringModel::TaskTemplate.count", 1 do
      post :create, xhr: true, params: { mentoring_model_id: @mentoring_model.id, duration_id_input: "7", mentoring_model_task_template: {
        required: "1", title: "some title", description: "description", role_id: @program.roles.for_mentoring.last.id, duration: 1, specific_date: "2012-12-28", date_assigner: MentoringModel::TaskTemplate::DueDateType::SPECIFIC_DATE
      }}
    end
    assert_response :success
    assert_equal "some title", assigns(:task_template).title
    assert_equal "description", assigns(:task_template).description
    assert assigns(:task_template).required?
    assert_equal @program.roles.for_mentoring.last, assigns(:task_template).role
    assert_equal 0, assigns(:task_template).duration
    assert_nil assigns(:task_template).associated_id
    assert_equal "2012-12-28", assigns(:task_template).specific_date.to_date.to_s
  end

  def test_goals_not_attributed_for_not_required_tasks
    goal_template = create_mentoring_model_goal_template
    assert_difference "MentoringModel::TaskTemplate.count", 1 do
      post :create, xhr: true, params: { mentoring_model_id: @mentoring_model.id, mentoring_model_task_template: {
        required: "0", title: "some title", description: "description", role_id: @program.roles.for_mentoring.last.id, duration: 1, goal_template_id: goal_template.id
      }}
    end
    assert_response :success
    assert_equal "some title", assigns(:task_template).title
    assert_equal "description", assigns(:task_template).description
    assert_nil assigns(:task_template).goal_template
    assert_false assigns(:task_template).required?
    assert_equal @program.roles.for_mentoring.last, assigns(:task_template).role
  end

  def test_goals_attributed_for_required_tasks
    goal_template = @mentoring_model.mentoring_model_goal_templates.create!(title: "Hello1", description: "Hello1Desc")
    assert_difference "MentoringModel::TaskTemplate.count", 1 do
      post :create, xhr: true, params: { mentoring_model_id: @mentoring_model.id, mentoring_model_task_template: {
        required: "1", title: "some title", description: "description", role_id: @program.roles.for_mentoring.last.id, duration: 1, goal_template_id: goal_template.id, date_assigner: MentoringModel::TaskTemplate::DueDateType::PREDECESSOR
      }}
    end
    assert_response :success
    assert_equal "some title", assigns(:task_template).title
    assert_equal "description", assigns(:task_template).description
    assert_equal goal_template, assigns(:task_template).goal_template
    assert assigns(:task_template).required?
    assert_equal @program.roles.for_mentoring.last, assigns(:task_template).role
  end

  def test_create_action_defaults_for_task_template
    post :create, xhr: true, params: { mentoring_model_id: @mentoring_model.id, mentoring_model_task_template: {duration: 7, role_id: @program.roles.for_mentoring.with_name([RoleConstants::STUDENT_NAME])[0].id, action_item_type: MentoringModel::TaskTemplate::ActionItem::DEFAULT}}
    assert_equal "Untitled Task", assigns(:task_template).title
  end

  def test_create_action_defaults_for_setup_meeting
    post :create, xhr: true, params: { mentoring_model_id: @mentoring_model.id, mentoring_model_task_template: {duration: 7, role_id: @program.roles.for_mentoring.with_name([RoleConstants::STUDENT_NAME])[0].id, action_item_type: MentoringModel::TaskTemplate::ActionItem::MEETING}}
    assert_equal "Set Up Meeting", assigns(:task_template).title
  end

  def test_create_action_defaults_for_create_goal
    post :create, xhr: true, params: { mentoring_model_id: @mentoring_model.id, mentoring_model_task_template: {duration: 7, role_id: @program.roles.for_mentoring.with_name([RoleConstants::STUDENT_NAME])[0].id, action_item_type: MentoringModel::TaskTemplate::ActionItem::GOAL}}
    assert_equal "Create Goal Plan", assigns(:task_template).title
  end

  def test_create_action_defaults_for_take_engagement_survey
    survey = EngagementSurvey.first
    post :create, xhr: true, params: { mentoring_model_id: @mentoring_model.id, mentoring_model_task_template: {duration: 7, role_id: @program.roles.with_name([RoleConstants::STUDENT_NAME])[0].id, action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id}}
    assert_equal survey.name, assigns(:task_template).title
  end

  def test_edit_action
    @task_template = create_mentoring_model_task_template
    @mentoring_model.mentoring_model_goal_templates.create!(title: "Hello1", description: "Hello1Desc")
    get :edit, xhr: true, params: { mentoring_model_id: @mentoring_model.id, id: @task_template.id}
    assert_response :success
    assert_template %r{mentoring_model/task_templates/_task_template_progressive_form}
    assert_equal @task_template, assigns(:task_template)
    assert_equal 1, assigns(:goal_templates_to_associate).size
    assert_nil assigns(:milestone_templates_to_associate)
    assert_nil assigns(:action_items_to_associate)
  end

  def test_edit_goal_template_to_associate_with_manual_progress
    @task_template = create_mentoring_model_task_template
    @mentoring_model.mentoring_model_goal_templates.create!(title: "Hello1", description: "Hello1Desc")
    @mentoring_model.update_attribute(:goal_progress_type, MentoringModel::GoalProgressType::MANUAL)
    get :edit, xhr: true, params: { mentoring_model_id: @mentoring_model.id, id: @task_template.id}
    assert_response :success
    assert_nil assigns(:goal_templates_to_associate)
  end

  def test_update_action
    @task_template = create_mentoring_model_task_template
    template_version_increases_by_one_and_triggers_sync_once "@mentoring_model" do
      put :update, xhr: true, params: { mentoring_model_id: @mentoring_model.id, id: @task_template.id, mentoring_model_task_template: {
        required: "false", title: "some title", description: "description", role_id: @program.roles.for_mentoring.last.id
      }}
    end
    @task_template.reload
    assert_response :success
    assert_equal "some title", assigns(:task_template).title
    assert_equal "description", assigns(:task_template).description
    assert_false assigns(:task_template).required?
    assert_equal @program.roles.for_mentoring.last, assigns(:task_template).role
  end

def test_update_action_with_vulnerable_content_with_version_v1
    current_user_is :f_admin
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v1")
    @task_template = create_mentoring_model_task_template
    assert_no_difference "VulnerableContentLog.count" do
      template_version_increases_by_one_and_triggers_sync_once "@mentoring_model" do
        put :update, xhr: true, params: { mentoring_model_id: @mentoring_model.id, id: @task_template.id, mentoring_model_task_template: {
          required: "false", title: "some title", description: "description<script>alert(10);</script>", role_id: @program.roles.for_mentoring.last.id
        }}
      end
    end
  end

def test_update_action_with_vulnerable_content_with_version_v2
    current_user_is :f_admin
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v2")
    @task_template = create_mentoring_model_task_template
    assert_difference "VulnerableContentLog.count" do
      template_version_increases_by_one_and_triggers_sync_once "@mentoring_model" do
        put :update, xhr: true, params: { mentoring_model_id: @mentoring_model.id, id: @task_template.id, mentoring_model_task_template: {
          required: "false", title: "some title", description: "description<script>alert(10);</script>", role_id: @program.roles.for_mentoring.last.id
        }}
      end
    end
  end

  def test_update_action_with_duration_id_input
    @task_template = create_mentoring_model_task_template
    put :update, xhr: true, params: { mentoring_model_id: @mentoring_model.id, duration_id_input: "7", id: @task_template.id, mentoring_model_task_template: {
      required: "1", title: "some title", description: "description", role_id: @program.roles.for_mentoring.last.id, duration: 7, date_assigner: MentoringModel::TaskTemplate::DueDateType::PREDECESSOR
    }}
    @task_template.reload
    assert_response :success
    assert_equal "some title", assigns(:task_template).title
    assert_equal "description", assigns(:task_template).description
    assert assigns(:task_template).required?
    assert_equal 49, assigns(:task_template).duration
  end

  def test_delete_action_for_goal_template
    @task_template = create_mentoring_model_task_template
    assert_difference "MentoringModel::TaskTemplate.count", -1 do
      delete :destroy, xhr: true, params: { mentoring_model_id: @mentoring_model.id, id: @task_template.id}
    end
    assert_response :success
  end

  # some permission tests

  def test_permission_denied_for_new_action
    deny_access_for_mentoring_model_tasks
    assert_permission_denied { get :new, xhr: true, params: { mentoring_model_id: @mentoring_model.id} }
  end

  def test_permission_denied_for_create_action
    deny_access_for_mentoring_model_tasks
    assert_permission_denied { post :create, xhr: true, params: { mentoring_model_id: @mentoring_model.id, mentoring_model_task_template: {title: "Hello", description: "HelloDesc"}} }
  end

  def test_permission_denied_for_edit_action
    @task_template = create_mentoring_model_task_template
    deny_access_for_mentoring_model_tasks
    assert_permission_denied { get :edit, xhr: true, params: { mentoring_model_id: @mentoring_model.id, id: @task_template.id} }
  end

  def test_permission_denied_for_update_action
    @task_template = create_mentoring_model_task_template
    deny_access_for_mentoring_model_tasks
    assert_permission_denied { put :update, xhr: true, params: { mentoring_model_id: @mentoring_model.id, id: @task_template.id, mentoring_model_task_template: {title: "Hello"}} }
  end

  def test_permission_denied_for_destroy_action
    @task_template = create_mentoring_model_task_template
    deny_access_for_mentoring_model_tasks
    assert_permission_denied { delete :destroy, xhr: true, params: { mentoring_model_id: @mentoring_model.id, id: @task_template.id} }
  end

  def test_update_positions
    @task_template = create_mentoring_model_task_template
    required_1 = create_mentoring_model_task_template(required: true, associated_id: nil)
    required_2 = create_mentoring_model_task_template(required: true, associated_id: required_1.id)
    optional_1 = create_mentoring_model_task_template(associated_id: required_2.id)
    optional_2 = create_mentoring_model_task_template(associated_id: optional_1.id)
    MentoringModel::TaskTemplate.compute_due_dates(@mentoring_model.mentoring_model_task_templates)
    assert_equal [0, 1, 2, 3, 4], @mentoring_model.reload.mentoring_model_task_templates.map(&:position)
    assert_equal [@task_template, required_1, required_2, optional_1, optional_2].map(&:id), @mentoring_model.reload.mentoring_model_task_templates.map(&:id)
    assert_nil @task_template.associated_id
    template_version_increases_by_one_and_triggers_sync_once "@mentoring_model" do
      post :update_positions, xhr: true, params: { id: @task_template.id, mentoring_model_id: @mentoring_model.id, mentoring_model_task_template: [required_1, required_2, optional_1, @task_template, optional_2].map(&:id)}
    end
    @task_template.reload
    assert_equal [0, 1, 2, 3, 4], @mentoring_model.reload.mentoring_model_task_templates.map(&:position)
    assert_equal [required_1, required_2, optional_1, @task_template, optional_2].map(&:id), @mentoring_model.reload.mentoring_model_task_templates.map(&:id)
    assert_equal required_2.id, @task_template.associated_id
  end

  def test_new_with_milestones_permission_denied
    milestone_template = create_mentoring_model_milestone_template
    get :new, xhr: true, params: { milestone_template_id: milestone_template.id, mentoring_model_id: @mentoring_model.id}
    assert_equal %Q[window.location.href = "#{mentoring_model_path(@mentoring_model)}";], response.body
  end

  def test_new_with_milestones_permission
    @mentoring_model.allow_manage_mm_milestones!(@admin_role)
    get :new, xhr: true, params: { mentoring_model_id: @mentoring_model.id}
    assert_equal %Q[window.location.href = "#{mentoring_model_path(@mentoring_model)}";], response.body
  end
  
  def test_new_with_milestones_success
    @mentoring_model.allow_manage_mm_milestones!(@admin_role)
    milestone_template = create_mentoring_model_milestone_template
    create_mentoring_model_task_template(milestone_template_id: milestone_template.id)
    required_task = create_mentoring_model_task_template(milestone_template_id: milestone_template.id, required: true)
    create_mentoring_model_task_template(milestone_template_id: milestone_template.id)

    get :new, xhr: true, params: { milestone_template_id: milestone_template.id, mentoring_model_id: @mentoring_model.id}
    assert_response :success

    assert_equal milestone_template.id, assigns(:milestone_template).id
    assert assigns(:task_template).new_record?
    assert_equal [required_task], assigns(:task_templates_to_associate)
    assert_equal 1, assigns(:milestone_templates_to_associate).count
  end

  def test_new_with_milestone_success_with_specific_date_tasks
    @mentoring_model.allow_manage_mm_milestones!(@admin_role)
    milestone_template = create_mentoring_model_milestone_template
    create_mentoring_model_task_template(milestone_template_id: milestone_template.id)
    required_task_1 = create_mentoring_model_task_template(milestone_template_id: milestone_template.id, specific_date: "2014-12-28", required: true)
    required_task_2 = create_mentoring_model_task_template(milestone_template_id: milestone_template.id, required: true)
    create_mentoring_model_task_template(milestone_template_id: milestone_template.id)

    get :new, xhr: true, params: { milestone_template_id: milestone_template.id, mentoring_model_id: @mentoring_model.id}
    assert_response :success

    assert_equal milestone_template.id, assigns(:milestone_template).id
    assert assigns(:task_template).new_record?
    assert_equal [required_task_2], assigns(:task_templates_to_associate)
    assert_equal 1, assigns(:milestone_templates_to_associate).count
  end

  def test_create_with_milestone_permission_denied
    @mentoring_model.deny_manage_mm_milestones!(@admin_role)
    milestone_template = create_mentoring_model_milestone_template

    post :create, xhr: true, params: { mentoring_model_id: @mentoring_model.id, mentoring_model_task_template: {
      required: "false", title: "Carrie Mathison", description: "Homeland", role_id: @program.roles.for_mentoring.last.id, duration: 1, milestone_template_id: milestone_template.id }}
    assert_equal %Q[window.location.href = "#{mentoring_model_path(@mentoring_model)}";], response.body
  end

  def test_create_with_milestone_success
    @mentoring_model.allow_manage_mm_milestones!(@admin_role)
    milestone_template = create_mentoring_model_milestone_template
    task_template = create_mentoring_model_task_template(milestone_template_id: milestone_template.id)

    post :create, xhr: true, params: { mentoring_model_id: @mentoring_model.id, mentoring_model_task_template: {
      required: "false", title: "Carrie Mathison", description: "Homeland", role_id: @program.roles.for_mentoring.last.id, duration: 1, milestone_template_id: milestone_template.id
    }}
    assert_response :success

    assert_equal "Carrie Mathison", assigns(:task_template).title
    assert_equal "Homeland", assigns(:task_template).description
    assert_equal [task_template, MentoringModel::TaskTemplate.last].collect(&:id), assigns(:all_task_templates).collect(&:id)
  end

  def test_create_without_milestones_when_admin_can_manage_milestones
    @mentoring_model.allow_manage_mm_milestones!(@admin_role)
    post :create, xhr: true, params: { mentoring_model_id: @mentoring_model.id, mentoring_model_task_template: {
      required: "false", title: "Carrie Mathison", description: "Homeland", role_id: @program.roles.for_mentoring.last.id, duration: 1
    }}
    assert_equal %Q[window.location.href = "#{mentoring_model_path(@mentoring_model)}";], response.body
  end

  def test_edit_success_with_milestones
    @mentoring_model.allow_manage_mm_milestones!(@admin_role)
    milestone_template = create_mentoring_model_milestone_template
    tt1 = create_mentoring_model_task_template(milestone_template_id: milestone_template.id)
    tt2 = create_mentoring_model_task_template(milestone_template_id: milestone_template.id, required: true)
    tt3 = create_mentoring_model_task_template(milestone_template_id: milestone_template.id, required: true)
    tt4 = create_mentoring_model_task_template(milestone_template_id: milestone_template.id, required: true, specific_date: "2014-12-28")

    get :edit, xhr: true, params: { id: tt1.id, mentoring_model_id: @mentoring_model.id}
    assert_response :success

    assert_equal_unordered [tt2, tt3].map(&:id), assigns(:task_templates_to_associate).map(&:id)
    assert_equal 1, assigns(:milestone_templates_to_associate).count
  end

  def test_edit_success_with_milestones2
    @mentoring_model.allow_manage_mm_milestones!(@admin_role)
    milestone_template = create_mentoring_model_milestone_template
    t1 = create_mentoring_model_task_template(duration: 2, required: true, milestone_template_id: milestone_template.id)
    t2 = create_mentoring_model_task_template(duration: 3, required: true, milestone_template_id: milestone_template.id)
    t3 = create_mentoring_model_task_template(duration: 2, required: true, associated_id: t1.id, milestone_template_id: milestone_template.id)
    t4 = create_mentoring_model_task_template(duration: 2, required: true, associated_id: t3.id, milestone_template_id: milestone_template.id)
    get :edit, xhr: true, params: { id: t3.id, mentoring_model_id: @mentoring_model.id}
    assert_response :success
    assert_equal_unordered [t1, t2].map(&:id), assigns(:task_templates_to_associate).map(&:id)
  end

  def test_edit_success_with_milestones_associated_tasks
    @mentoring_model.allow_manage_mm_milestones!(@admin_role)
    milestone_template = create_mentoring_model_milestone_template
    milestone_template1 = create_mentoring_model_milestone_template
    tt1 = create_mentoring_model_task_template(milestone_template_id: milestone_template.id)
    tt2 = create_mentoring_model_task_template(milestone_template_id: milestone_template.id, required: true)
    tt3 = create_mentoring_model_task_template(milestone_template_id: milestone_template.id, required: true)
    tt4 = create_mentoring_model_task_template(milestone_template_id: milestone_template.id, required: true, specific_date: "2014-12-28")
    tt5 = create_mentoring_model_task_template(required: true, milestone_template_id: milestone_template1.id)

    get :edit, xhr: true, params: { id: tt2.id, mentoring_model_id: @mentoring_model.id}
    assert_response :success

    assert_equal_unordered [tt3].map(&:id), assigns(:task_templates_to_associate).map(&:id)
  end

  def test_update_success_with_milestone_templates
    @mentoring_model.allow_manage_mm_milestones!(@admin_role)
    milestone_template = create_mentoring_model_milestone_template
    tt1 = create_mentoring_model_task_template(milestone_template_id: milestone_template.id)

    put :update, xhr: true, params: { mentoring_model_id: @mentoring_model.id, id: tt1.id, mentoring_model_task_template: {
      required: "false", title: "No Problem", description: "Carrie Mathison", role_id: @program.roles.for_mentoring.last.id, milestone_template_id: milestone_template.id}}
    assert_response :success

    assert_equal "No Problem", assigns(:task_template).title
    assert_equal "Carrie Mathison", assigns(:task_template).description
  end

  def test_update_with_milestone_templates_permission_denied
    tt1 = create_mentoring_model_task_template

    put :update, xhr: true, params: { mentoring_model_id: @mentoring_model.id, id: tt1.id, mentoring_model_task_template: {
      required: "false", title: "No Problem", description: "Carrie Mathison", role_id: @program.roles.for_mentoring.last.id, milestone_template_id: 3 }}
    assert_equal %Q[window.location.href = "#{mentoring_model_path(@mentoring_model)}";], response.body
  end

  def test_destroy
    @mentoring_model.allow_manage_mm_milestones!(@admin_role)
    milestone_template1 = create_mentoring_model_milestone_template
    milestone_template2 = create_mentoring_model_milestone_template
    tt1 = create_mentoring_model_task_template(milestone_template_id: milestone_template1.id)
    tt2 = create_mentoring_model_task_template(milestone_template_id: milestone_template1.id)
    tt3 = create_mentoring_model_task_template(milestone_template_id: milestone_template2.id)

    template_version_increases_by_one_and_triggers_sync_once "@mentoring_model" do
      delete :destroy, xhr: true, params: { id: tt1.id, mentoring_model_id: @mentoring_model.id}
    end
    assert_response :success

    assert_equal({milestone_template1.id => [tt2], milestone_template2.id => [tt3]}, assigns(:all_task_templates))
  end

  def test_update_with_milestones_with_position_changes
    @mentoring_model.allow_manage_mm_milestones!(@admin_role)
    milestone_template1 = create_mentoring_model_milestone_template
    milestone_template2 = create_mentoring_model_milestone_template

    tt1 = create_mentoring_model_task_template(milestone_template_id: milestone_template1.id, required: true, duration: 5)
    tt2 = create_mentoring_model_task_template(milestone_template_id: milestone_template2.id, required: true, duration: 7, associated_id: tt1.id)
    tt3 = create_mentoring_model_task_template(milestone_template_id: milestone_template2.id, required: true, duration: 6)
    task_templates = MentoringModel::TaskTemplate.compute_due_dates([tt1, tt2, tt3], skip_positions: true)
    MentoringModel::TaskTemplate.update_due_positions([tt1])
    MentoringModel::TaskTemplate.update_due_positions([tt2, tt3])

    assert_equal [0, 1, 0], [tt1, tt2, tt3].collect(&:reload).collect(&:position)

    put :update, xhr: true, params: { id: tt3.id, mentoring_model_id: @mentoring_model.id, mentoring_model_task_template: {
        title: "No Problem", description: "Carrie Mathison", role_id: @program.roles.for_mentoring.last.id, milestone_template_id: milestone_template1.id, duration: 20, required: "1"}}
    assert_response :success

    [tt1, tt2, tt3].collect(&:reload)
    assert_equal [nil, tt1.id, nil], [tt1, tt2, tt3].collect(&:associated_id)
    assert_equal [5, 7, 20], [tt1, tt2, tt3].collect(&:duration)
    assert_equal [0, 0, 1], [tt1, tt2, tt3].collect(&:position)
  end

  def test_task_template_new_required_task_templates
    @mentoring_model.allow_manage_mm_milestones!(@admin_role)
    milestone_template1 = create_mentoring_model_milestone_template
    milestone_template2 = create_mentoring_model_milestone_template
    task_template1 = create_mentoring_model_task_template(milestone_template_id: milestone_template1.id, required: true, duration: 5)
    task_template2 = create_mentoring_model_task_template(milestone_template_id: milestone_template1.id, required: true, duration: 1)
    task_template3 = create_mentoring_model_task_template(milestone_template_id: milestone_template2.id, required: true, duration: 6)

    get :new, xhr: true, params: { milestone_template_id: milestone_template1.id, mentoring_model_id: @mentoring_model.id}
    assert_response :success

    assert_equal [task_template2, task_template1].collect(&:id), assigns(:task_templates_to_associate).collect(&:id)
    assert_equal [task_template2, task_template1].collect(&:role_id), assigns(:task_templates_to_associate).collect(&:role_id)
  end

  def test_task_template_edit_required_task_templates
    @mentoring_model.allow_manage_mm_milestones!(@admin_role)
    milestone_template1 = create_mentoring_model_milestone_template
    milestone_template2 = create_mentoring_model_milestone_template
    task_template1 = create_mentoring_model_task_template(milestone_template_id: milestone_template1.id, required: true, duration: 5)
    task_template2 = create_mentoring_model_task_template(milestone_template_id: milestone_template1.id, required: true, duration: 1)
    task_template3 = create_mentoring_model_task_template(milestone_template_id: milestone_template2.id, required: true, duration: 6)

    get :edit, xhr: true, params: { id: task_template3.id, mentoring_model_id: @mentoring_model.id}
    assert_response :success

    assert_equal [task_template2, task_template1].collect(&:id), assigns(:task_templates_to_associate).collect(&:id)
    assert_equal [task_template2, task_template1].collect(&:role_id), assigns(:task_templates_to_associate).collect(&:role_id)
  end

  def test_create_unassigned_task_templates
    post :create, xhr: true, params: { mentoring_model_id: @mentoring_model.id, mentoring_model_task_template: {
      required: "false", title: "some title", description: "description", role_id: "", duration: 1
    }}
    assert_response :success

    assert_equal "some title", assigns(:task_template).title
    assert_equal "description", assigns(:task_template).description
    assert_false assigns(:task_template).required?
    assert_nil assigns(:task_template).role
  end

  def test_create_unassigned_task_templates_with_different_role_id_input
    post :create, xhr: true, params: { mentoring_model_id: @mentoring_model.id, mentoring_model_task_template: {
      required: "false", title: "some title", description: "description", role_id: nil, duration: 1
    }}
    assert_response :success

    assert_equal "some title", assigns(:task_template).title
    assert_equal "description", assigns(:task_template).description
    assert_false assigns(:task_template).required?
    assert_nil assigns(:task_template).role
  end

  def test_new_for_program_with_disabled_ongoing_mentoring
    #disabling ongoing mentoring
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_permission_denied do
      get :new, xhr: true, params: { mentoring_model_id: @mentoring_model.id}
    end
  end

  def test_check_chronological_order_is_maintained
    @mentoring_model.mentoring_model_milestone_templates.destroy_all
    
    mt1 = create_mentoring_model_milestone_template({title: "Template1"})
    mt2 = create_mentoring_model_milestone_template({title: "Template2"})
    mt3 = create_mentoring_model_milestone_template({title: "Template3"})
    mt4 = create_mentoring_model_milestone_template({title: "Template3"})

    tt1 = create_mentoring_model_task_template
    tt2 = create_mentoring_model_task_template
    tt3 = create_mentoring_model_task_template

    tt1.update_attributes(:milestone_template_id => mt1.id, :required => true, :duration => 10)
    tt2.update_attributes(:milestone_template_id => mt2.id, :required => true, :duration => 20)
    tt3.update_attributes(:milestone_template_id => mt3.id, :required => true, :duration => 30)


    put :check_chronological_order_is_maintained, xhr: true, params: { mentoring_model_id: @mentoring_model.reload.id, :mentoring_model_task_template => {:duration => "5", :required => "1", :milestone_template_id => mt2.id}, :duration_id_input => "7"}

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal true, json_response["show_warning"]
    assert assigns(:should_check_milestone_order)
    assert_equal [[mt1.position, 10, 10], [mt2.position, 20, 35], [mt3.position, 30, 30]], assigns(:current_first_and_last_required_task_in_milestones_list)

    put :check_chronological_order_is_maintained, xhr: true, params: { mentoring_model_id: @mentoring_model.reload.id, :mentoring_model_task_template => {:duration => "5", :required => "1", :milestone_template_id => mt4.id}, :duration_id_input => "7"}

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal false, json_response["show_warning"]
    assert assigns(:should_check_milestone_order)
    assert_equal [[mt1.position, 10, 10], [mt2.position, 20, 20], [mt3.position, 30, 30], [mt4.position, 35, 35]], assigns(:current_first_and_last_required_task_in_milestones_list)

    mt1.update_attribute(:position, 1)
    mt2.update_attribute(:position, 0)

    put :check_chronological_order_is_maintained, xhr: true, params: { mentoring_model_id: @mentoring_model.reload.id, :mentoring_model_task_template => {:duration => "5", :duration_id_input => "5", :required => true, :milestone_template_id => mt2.id}}

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal false, json_response["show_warning"]
    assert_false assigns(:should_check_milestone_order)
    assert_equal [[mt2.position, 20, 20], [mt1.position, 10, 10], [mt3.position, 30, 30]], assigns(:current_first_and_last_required_task_in_milestones_list)
  end

  private

  def deny_access_for_mentoring_model_tasks
    create_object_role_permission("manage_mm_tasks", {action: 'deny'})
  end
end