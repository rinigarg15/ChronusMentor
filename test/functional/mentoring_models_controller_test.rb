require_relative './../test_helper.rb'

class MentoringModelsControllerTest < ActionController::TestCase

  def setup
    super
    user = users(:f_admin)
    program = user.program
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    @mentoring_model = program.default_mentoring_model

    current_user_is user
  end

  def test_multiple_templates_permission_denied
    programs(:albers).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, false)
    assert_permission_denied do
      get :index
    end
  end

  def test_multiple_templates_enabled_success
    get :index
    assert_response :success
    assert_equal [@mentoring_model], assigns(:mentoring_models)
    assert_select "div#page_heading", text: /Mentoring Connection Plan Templates/
  end

  def test_index_action
    mentoring_model1 = create_mentoring_model

    get :index
    assert_response :success
    assert_equal [@mentoring_model, mentoring_model1], assigns(:mentoring_models)
    assert_equal ObjectPermission.all.to_a, assigns(:object_permissions).to_a
    assert_select "div#page_heading", text: /Mentoring Connection Plan Templates/
  end

  def test_show_action
    create_object_role_permission("manage_mm_goals")
    goal_template = @mentoring_model.mentoring_model_goal_templates.create!(title: "Hello1", description: "Hello1Desc")

    get :show, params: { id: @mentoring_model.id}
    assert_response :success
    assert_match GroupTerminationNotification.mailer_attributes[:uid], @response.body
    assert_equal 1, assigns(:all_goal_templates).count
    assert_equal @mentoring_model.active_groups.size, assigns(:connections_getting_reordered_count)
  end

  def test_show_action_without_permission
    create_object_role_permission("manage_mm_goals", action: 'deny')
    goal_template = @mentoring_model.mentoring_model_goal_templates.create!(title: "Hello1", description: "Hello1Desc")

    get :show, params: { id: @mentoring_model.id}
    assert_response :success
    assert_nil assigns(:all_goal_templates)
  end

  def test_setup_action_hashes
    login_as_super_user
    get :setup, params: { id: @mentoring_model.id}
    assert_response :success
    assert_false assigns(:admin_hash)["manage_mm_milestones"]
    assert_false assigns(:users_hash)["manage_mm_milestones"]
    assert assigns(:admin_hash)["manage_mm_goals"]
    assert assigns(:users_hash)["manage_mm_goals"]
    assert assigns(:admin_hash)["manage_mm_tasks"]
    assert assigns(:users_hash)["manage_mm_tasks"]
    assert_nil assigns(:admin_hash)["manage_mm_meetings"]
    assert assigns(:users_hash)["manage_mm_meetings"]
    assert assigns(:admin_hash)["manage_mm_messages"]
    assert_nil assigns(:users_hash)["manage_mm_messages"]
    assert assigns(:admin_hash)["manage_mm_engagement_surveys"]
    assert_nil assigns(:users_hash)["manage_mm_engagement_surveys"]
  end

  def test_upload_from_templates
    login_as_super_user
    post :upload_from_templates, params: { id: @mentoring_model.id, mentoring_model: {template: fixture_file_upload(File.join('files', 'mentoring_model', 'test.csv'), 'text/csv')}}
    assert_equal "The mentoring connection plan template has been set up successfully from the template file", flash[:notice]
    program = programs(:albers)
    assert_equal ["Goal 1", "Goal 2"], @mentoring_model.reload.mentoring_model_goal_templates.collect(&:title)
    assert_equal ["Milestone 1", "Milestone 2"], @mentoring_model.mentoring_model_milestone_templates.collect(&:title)
    assert_equal ["Task 1", "Task 2", "Task 3"], @mentoring_model.mentoring_model_milestone_templates[0].mentoring_model_task_templates.collect(&:title)
    assert_equal ["Task 4", "Task 5", "Task 6", "Task 7"], @mentoring_model.mentoring_model_milestone_templates[1].mentoring_model_task_templates.collect(&:title)
    assert @mentoring_model.can_manage_mm_milestones?(program.roles)
    assert @mentoring_model.can_manage_mm_goals?(program.roles)
    assert @mentoring_model.can_manage_mm_tasks?(program.roles)
    assert @mentoring_model.can_manage_mm_meetings?(program.roles)
    assert @mentoring_model.can_manage_mm_messages?(program.roles)
    assert @mentoring_model.can_manage_mm_engagement_surveys?(program.roles)
    assert_redirected_to setup_mentoring_model_path(@mentoring_model, uploaded_successfully: true)
  end

  def test_upload_from_templates_with_diff_content_type_for_a_csv
    login_as_super_user
    post :upload_from_templates, params: { id: @mentoring_model.id, mentoring_model: {template: fixture_file_upload(File.join('files', 'mentoring_model', 'test.csv'), 'application/octet-stream')}}
    assert_equal "The mentoring connection plan template has been set up successfully from the template file", flash[:notice]
    program = programs(:albers)
    assert_equal ["Goal 1", "Goal 2"], @mentoring_model.reload.mentoring_model_goal_templates.collect(&:title)
    assert_equal ["Milestone 1", "Milestone 2"], @mentoring_model.mentoring_model_milestone_templates.collect(&:title)
    assert_equal ["Task 1", "Task 2", "Task 3"], @mentoring_model.mentoring_model_milestone_templates[0].mentoring_model_task_templates.collect(&:title)
    assert_equal ["Task 4", "Task 5", "Task 6", "Task 7"], @mentoring_model.mentoring_model_milestone_templates[1].mentoring_model_task_templates.collect(&:title)
    assert @mentoring_model.can_manage_mm_milestones?(program.roles)
    assert @mentoring_model.can_manage_mm_goals?(program.roles)
    assert @mentoring_model.can_manage_mm_tasks?(program.roles)
    assert @mentoring_model.can_manage_mm_meetings?(program.roles)
    assert @mentoring_model.can_manage_mm_messages?(program.roles)
    assert @mentoring_model.can_manage_mm_engagement_surveys?(program.roles)
    assert_redirected_to setup_mentoring_model_path(@mentoring_model, uploaded_successfully: true)
  end

  def test_upload_from_templates_csv_fail
    login_as_super_user
    post :upload_from_templates, params: { id: @mentoring_model.id, mentoring_model: {template: fixture_file_upload(File.join('files', 'mentoring_model', 'test_csv_error.csv'), 'text/csv')}}
    assert_equal "The mentoring connection plan template failed to set up from the template file while processing CSV file", flash[:error]
    assert_redirected_to setup_mentoring_model_path(@mentoring_model, uploaded_successfully: false)
  end

  def test_upload_from_templates_milestone_fail
    login_as_super_user
    post :upload_from_templates, params: { id: @mentoring_model.id, mentoring_model: {template: fixture_file_upload(File.join('files', 'mentoring_model', 'test_milestone_error.csv'), 'text/csv')}}
    assert_equal "The mentoring connection plan template failed to set up from the template file while processing milestones content", flash[:error]
    assert_redirected_to setup_mentoring_model_path(@mentoring_model, uploaded_successfully: false)
  end

  def test_upload_from_templates_goal_fail
    login_as_super_user
    post :upload_from_templates, params: { id: @mentoring_model.id, mentoring_model: {template: fixture_file_upload(File.join('files', 'mentoring_model', 'test_goal_error.csv'), 'text/csv')}}
    assert_equal "The mentoring connection plan template failed to set up from the template file while processing goals content", flash[:error]
    assert_redirected_to setup_mentoring_model_path(@mentoring_model, uploaded_successfully: false)
  end

  def test_upload_from_templates_task_fail
    login_as_super_user
    post :upload_from_templates, params: { id: @mentoring_model.id, mentoring_model: {template: fixture_file_upload(File.join('files', 'mentoring_model', 'test_task_error.csv'), 'text/csv')}}
    assert_equal "The mentoring connection plan template failed to set up from the template file while processing tasks content. Also please check whether the survey IDs used are valid.", flash[:error]
    assert_redirected_to setup_mentoring_model_path(@mentoring_model, uploaded_successfully: false)
  end

  def test_index_task_template_assigns
    create_mentoring_model_task_template
    @mentoring_model.deny_manage_mm_milestones!(programs(:albers).roles.with_name(RoleConstants::ADMIN_NAME))

    get :show, params: { id: @mentoring_model.id}
    assert_response :success
    assert_equal @mentoring_model.mentoring_model_task_templates, assigns(:mentoring_model_task_templates)
  end

  def test_index_instance_vars
    admin_role = programs(:albers).get_role(RoleConstants::ADMIN_NAME)
    milestone_template = create_mentoring_model_milestone_template
    create_mentoring_model_task_template(milestone_template_id: milestone_template.id)
    create_mentoring_model_goal_template
    @mentoring_model.deny_manage_mm_tasks!(admin_role)
    @mentoring_model.deny_manage_mm_milestones!(admin_role)
    @mentoring_model.deny_manage_mm_goals!(admin_role)

    get :show, params: { id: @mentoring_model.id}
    assert_response :success
    assert_nil assigns(:all_goal_templates)
    assert assigns(:mentoring_model_task_templates).blank?
    assert_nil assigns(:mentoring_model_milestone_templates)

    assert_false @mentoring_model.can_manage_mm_tasks?(admin_role)
    assert_false @mentoring_model.can_manage_mm_milestones?(admin_role)
    assert_false @mentoring_model.can_manage_mm_goals?(admin_role)
  end

  def test_index_instance_vars_with_goals_and_tasks_enabled
    admin_role = programs(:albers).get_role(RoleConstants::ADMIN_NAME)
    milestone_template = create_mentoring_model_milestone_template
    create_mentoring_model_task_template(milestone_template_id: milestone_template.id)
    create_mentoring_model_goal_template
    @mentoring_model.deny_manage_mm_milestones!(admin_role)
    @mentoring_model.allow_manage_mm_goals!(admin_role)
    @mentoring_model.allow_manage_mm_tasks!(admin_role)

    get :show, params: { id: @mentoring_model.id}
    assert_response :success
    assert assigns(:all_goal_templates).present?
    assert assigns(:mentoring_model_task_templates).present?
    assert_nil assigns(:mentoring_model_milestone_templates)

    assert @mentoring_model.can_manage_mm_tasks?(admin_role)
    assert_false @mentoring_model.can_manage_mm_milestones?(admin_role)
    assert @mentoring_model.can_manage_mm_goals?(admin_role)
  end

  def test_index_instance_vars_with_goals_tasks_milestones_enabled
    admin_role = programs(:albers).get_role(RoleConstants::ADMIN_NAME)
    milestone_template = create_mentoring_model_milestone_template
    create_mentoring_model_task_template(milestone_template_id: milestone_template.id)
    create_mentoring_model_goal_template
    @mentoring_model.allow_manage_mm_goals!(admin_role)
    @mentoring_model.allow_manage_mm_tasks!(admin_role)
    @mentoring_model.allow_manage_mm_milestones!(admin_role)

    get :show, params: { id: @mentoring_model.id}
    assert_response :success
    assert assigns(:all_goal_templates).present?
    assert assigns(:mentoring_model_task_templates).present?
    assert assigns(:mentoring_model_task_templates).is_a?(Hash)
    assert assigns(:mentoring_model_milestone_templates)

    assert @mentoring_model.can_manage_mm_tasks?(admin_role)
    assert @mentoring_model.can_manage_mm_milestones?(admin_role)
    assert @mentoring_model.can_manage_mm_goals?(admin_role)
  end

  def test_index_instance_vars_with_facilitation_template_enabled
    admin_role = programs(:albers).get_role(RoleConstants::ADMIN_NAME)
    milestone_template = create_mentoring_model_milestone_template
    task_template_1 = create_mentoring_model_task_template(milestone_template_id: milestone_template.id, duration: 1, required: true)
    goal_template = create_mentoring_model_goal_template
    task_template_2 = create_mentoring_model_task_template(milestone_template_id: milestone_template.id, duration: 10, required: true)
    facilitation_template_1 = create_mentoring_model_facilitation_template(milestone_template_id: milestone_template.id, send_on: 5)
    facilitation_template_2 = create_mentoring_model_facilitation_template(milestone_template_id: milestone_template.id, send_on: 15)
    @mentoring_model.allow_manage_mm_goals!(admin_role)
    @mentoring_model.allow_manage_mm_tasks!(admin_role)
    @mentoring_model.allow_manage_mm_milestones!(admin_role)
    @mentoring_model.allow_manage_mm_messages!(admin_role)

    get :show, params: { id: @mentoring_model.id}
    assert_response :success
    assert assigns(:all_goal_templates).present?
    assert assigns(:mentoring_model_task_templates).present?
    assert assigns(:mentoring_model_task_templates).is_a?(Hash)
    assert_equal [task_template_1, facilitation_template_1, task_template_2, facilitation_template_2], assigns(:mentoring_model_task_templates)[milestone_template.id]
    assert assigns(:mentoring_model_milestone_templates)

    assert @mentoring_model.can_manage_mm_tasks?(admin_role)
    assert @mentoring_model.can_manage_mm_milestones?(admin_role)
    assert @mentoring_model.can_manage_mm_goals?(admin_role)
  end

  def test_permission_denied_on_setup_action
    get :setup, params: { id: @mentoring_model.id}
    assert_redirected_to super_login_path
  end

  def test_permission_denied_on_upload_from_templates_action
    post :upload_from_templates, params: { id: @mentoring_model.id}
    assert_redirected_to super_login_path
  end

  def test_permission_denied_on_create_action
    current_user_is :f_mentor
    post :create_template_objects, params: { id: @mentoring_model.id}
    assert_redirected_to super_login_path
  end

  def test_permission_denied_when_mentoring_connection_v2_is_disabled
    programs(:albers).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, false)

    login_as_super_user
    assert_permission_denied do
      post :create_template_objects, params: { id: @mentoring_model.id}
    end
  end

  def test_permission_denied_template_has_connections
    @mentoring_model.program.groups[0].update_attribute(:mentoring_model_id, @mentoring_model.id)
    admin = {"manage_mm_milestones"=>"1", "manage_mm_goals"=>"1", "manage_mm_tasks"=>"1", "manage_mm_messages"=>"1", "manage_mm_meetings"=>"1", "manage_mm_engagement_surveys"=>"1"}
    users = {"manage_mm_milestones"=>"0", "manage_mm_goals"=>"1", "manage_mm_tasks"=>"0", "manage_mm_messages"=>"1", "manage_mm_meetings"=>"0", "manage_mm_engagement_surveys"=>"0"}
    permissions = { "admin" => admin, "users" => users }
    mentoring_model_params = { "allow_due_date_edit" => true, "allow_messaging" => true, "allow_forum" => false }

    login_as_super_user
    assert_no_difference("@mentoring_model.object_role_permissions.count") do
      post :create_template_objects, params: { id: @mentoring_model.id, permissions: permissions, mentoring_model: mentoring_model_params, set_up_and_continue_later: "true"}
    end
    assert_redirected_to mentoring_models_path

    @mentoring_model.reload
    assert @mentoring_model.allow_due_date_edit
    assert @mentoring_model.allow_messaging
    assert_false @mentoring_model.allow_forum
  end

  def test_create_action
    roles_hash = programs(:albers).roles.select([:id, :name]).for_mentoring_models.group_by(&:name)
    admin_role = programs(:albers).roles.with_name(RoleConstants::ADMIN_NAME)
    @mentoring_model.allow_manage_mm_milestones!(admin_role)
    admin = {"manage_mm_milestones"=>"1", "manage_mm_goals"=>"1", "manage_mm_tasks"=>"1", "manage_mm_messages"=>"1", "manage_mm_meetings"=>"1", "manage_mm_engagement_surveys"=>"1"}
    users = {"manage_mm_milestones"=>"0", "manage_mm_goals"=>"1", "manage_mm_tasks"=>"0", "manage_mm_messages"=>"1", "manage_mm_meetings"=>"0", "manage_mm_engagement_surveys"=>"0"}
    permissions = { "admin" => admin, "users" => users }
    mentoring_model_params = { "allow_due_date_edit" => false, "allow_messaging" => false, "allow_forum" => true, "forum_help_text" => "Group Forum Help!" }

    login_as_super_user
    post :create_template_objects, params: { id: @mentoring_model.id, permissions: permissions, mentoring_model: mentoring_model_params}
    assert_redirected_to mentoring_model_path(@mentoring_model)

    @mentoring_model.reload
    assert @mentoring_model.send("can_manage_mm_milestones?", roles_hash[RoleConstants::ADMIN_NAME].first)
    assert @mentoring_model.send("can_manage_mm_goals?", roles_hash[RoleConstants::ADMIN_NAME].first)
    assert @mentoring_model.send("can_manage_mm_tasks?", roles_hash[RoleConstants::ADMIN_NAME].first)
    assert @mentoring_model.send("can_manage_mm_messages?", roles_hash[RoleConstants::ADMIN_NAME].first)
    assert @mentoring_model.send("can_manage_mm_meetings?", roles_hash[RoleConstants::ADMIN_NAME].first)
    assert @mentoring_model.send("can_manage_mm_engagement_surveys?", roles_hash[RoleConstants::ADMIN_NAME].first)

    assert_false @mentoring_model.send("can_manage_mm_milestones?", roles_hash[RoleConstants::MENTOR_NAME].first)
    assert @mentoring_model.send("can_manage_mm_goals?", roles_hash[RoleConstants::MENTOR_NAME].first)
    assert_false @mentoring_model.send("can_manage_mm_tasks?", roles_hash[RoleConstants::MENTOR_NAME].first)
    assert @mentoring_model.send("can_manage_mm_messages?", roles_hash[RoleConstants::MENTOR_NAME].first)
    assert_false @mentoring_model.send("can_manage_mm_meetings?", roles_hash[RoleConstants::MENTOR_NAME].first)
    assert_false @mentoring_model.send("can_manage_mm_engagement_surveys?", roles_hash[RoleConstants::MENTOR_NAME].first)

    assert_false @mentoring_model.send("can_manage_mm_milestones?", roles_hash[RoleConstants::STUDENT_NAME].first)
    assert @mentoring_model.send("can_manage_mm_goals?", roles_hash[RoleConstants::STUDENT_NAME].first)
    assert_false @mentoring_model.send("can_manage_mm_tasks?", roles_hash[RoleConstants::STUDENT_NAME].first)
    assert @mentoring_model.send("can_manage_mm_messages?", roles_hash[RoleConstants::STUDENT_NAME].first)
    assert_false @mentoring_model.send("can_manage_mm_meetings?", roles_hash[RoleConstants::STUDENT_NAME].first)
    assert_false @mentoring_model.send("can_manage_mm_engagement_surveys?", roles_hash[RoleConstants::STUDENT_NAME].first)

    assert_false @mentoring_model.allow_due_date_edit
    assert_false @mentoring_model.allow_messaging
    assert @mentoring_model.allow_forum
    assert_equal "Group Forum Help!", @mentoring_model.forum_help_text
  end

  def test_create_action_for_change_in_meeting_permissions
    roles_hash = programs(:albers).roles.select([:id, :name]).for_mentoring_models.group_by(&:name)
    @mentoring_model.allow_manage_mm_meetings!(programs(:albers).roles.with_name([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]))
    create_mentoring_model_task_template(action_item_type: MentoringModel::TaskTemplate::ActionItem::MEETING)
    create_mentoring_model_task_template(action_item_type: MentoringModel::TaskTemplate::ActionItem::MEETING)
    create_mentoring_model_task_template
    assert_equal 3, @mentoring_model.mentoring_model_task_templates.count
    assert_equal 2, @mentoring_model.mentoring_model_task_templates.select{|task_template| task_template.is_meeting_action_item? }.count
    admin = {"manage_mm_milestones"=>"1", "manage_mm_goals"=>"1", "manage_mm_tasks"=>"1", "manage_mm_messages"=>"1", "manage_mm_meetings"=>"1", "manage_mm_engagement_surveys"=>"1"}
    users = {"manage_mm_milestones"=>"0", "manage_mm_goals"=>"1", "manage_mm_tasks"=>"0", "manage_mm_messages"=>"1", "manage_mm_meetings"=>"0", "manage_mm_engagement_surveys"=>"0"}
    permissions = { "admin" => admin, "users" => users }
    mentoring_model_params = { "allow_due_date_edit" => true, "allow_messaging" => true, "allow_forum" => false }

    login_as_super_user
    post :create_template_objects, params: { id: @mentoring_model.id, permissions: permissions, mentoring_model: mentoring_model_params, "set_up_and_proceed" => "true"}
    assert_redirected_to mentoring_model_path(@mentoring_model)

    @mentoring_model.reload
    assert_false @mentoring_model.send("can_manage_mm_meetings?", roles_hash[RoleConstants::MENTOR_NAME].first)
    assert_false @mentoring_model.send("can_manage_mm_meetings?", roles_hash[RoleConstants::STUDENT_NAME].first)
    assert_equal 3, @mentoring_model.mentoring_model_task_templates.count
    assert_equal 0, @mentoring_model.mentoring_model_task_templates.select{|task_template| task_template.is_meeting_action_item? }.count
  end

  def test_create_action_for_destroying_templates
    admin_role = programs(:albers).get_role(RoleConstants::ADMIN_NAME)
    @mentoring_model.allow_manage_mm_goals!(admin_role)
    @mentoring_model.allow_manage_mm_tasks!(admin_role)
    @mentoring_model.allow_manage_mm_milestones!(admin_role)
    @mentoring_model.allow_manage_mm_messages!(admin_role)
    @mentoring_model.allow_manage_mm_engagement_surveys!(admin_role)

    milestone_template = create_mentoring_model_milestone_template
    create_mentoring_model_goal_template
    create_mentoring_model_task_template(milestone_template_id: milestone_template.id)
    create_mentoring_model_facilitation_template
    create_mentoring_model_engagement_survey_task_template(milestone_template_id: milestone_template.id)

    assert_equal 2, @mentoring_model.mentoring_model_task_templates.count
    assert_equal 1, @mentoring_model.mentoring_model_goal_templates.count
    assert_equal 1, @mentoring_model.mentoring_model_milestone_templates.count
    assert_equal 1, @mentoring_model.mentoring_model_facilitation_templates.count
    assert_equal 1, @mentoring_model.mentoring_model_task_templates.of_engagement_survey_type.count

    admin = {"manage_mm_milestones"=>"0", "manage_mm_goals"=>"0", "manage_mm_tasks"=>"0", "manage_mm_messages"=>"0", "manage_mm_meetings"=>"1", "manage_mm_engagement_surveys"=>"0"}
    users = {"manage_mm_milestones"=>"0", "manage_mm_goals"=>"1", "manage_mm_tasks"=>"0", "manage_mm_messages"=>"1", "manage_mm_meetings"=>"0", "manage_mm_engagement_surveys"=>"0"}
    permissions = { "admin" => admin, "users" => users }
    mentoring_model_params = { "allow_due_date_edit" => true, "allow_messaging" => true, "allow_forum" => false }

    login_as_super_user
    post :create_template_objects, params: { id: @mentoring_model.id, permissions: permissions, mentoring_model: mentoring_model_params}

    assert_equal 0, @mentoring_model.mentoring_model_task_templates.count
    assert_equal 0, @mentoring_model.mentoring_model_goal_templates.count
    assert_equal 0, @mentoring_model.mentoring_model_milestone_templates.count
    assert_equal 0, @mentoring_model.mentoring_model_facilitation_templates.count
    assert_equal 0, @mentoring_model.mentoring_model_task_templates.of_engagement_survey_type.count
  end

  def test_build_default_milestone_and_associated_task_template_on_create_action
    roles_hash = programs(:albers).roles.select([:id, :name]).for_mentoring_models.group_by(&:name)
    create_mentoring_model_task_template
    facilitation_template = create_mentoring_model_facilitation_template
    assert_equal 0, MentoringModel::MilestoneTemplate.count
    admin = {"manage_mm_milestones"=>"1", "manage_mm_goals"=>"0", "manage_mm_tasks"=>"1", "manage_mm_messages"=>"1", "manage_mm_meetings"=>"0"}
    users = {"manage_mm_milestones"=>"0", "manage_mm_goals"=>"1", "manage_mm_tasks"=>"0", "manage_mm_messages"=>"0", "manage_mm_meetings"=>"0"}
    permissions = { "admin" => admin, "users" => users, goal_progress_type: MentoringModel::GoalProgressType::MANUAL }
    mentoring_model_params = { "allow_due_date_edit" => true, "allow_messaging" => true, "allow_forum" => false }

    login_as_super_user
    post :create_template_objects, params: { id: @mentoring_model.id, permissions: permissions, mentoring_model: mentoring_model_params}

    assert_equal 1, MentoringModel::MilestoneTemplate.count
    mentoring_model_milestone_template = MentoringModel::MilestoneTemplate.last
    assert_equal 0, mentoring_model_milestone_template.position
    assert_equal [facilitation_template], mentoring_model_milestone_template.mentoring_model_facilitation_templates
    assert_equal MentoringModel::GoalProgressType::AUTO, @mentoring_model.reload.goal_progress_type
  end

  def test_goal_progress_update
    roles_hash = programs(:albers).roles.select([:id, :name]).for_mentoring_models.group_by(&:name)
    admin = {"manage_mm_milestones"=>"1", "manage_mm_goals"=>"1", "manage_mm_tasks"=>"1", "manage_mm_messages"=>"1", "manage_mm_meetings"=>"0"}
    users = {"manage_mm_milestones"=>"0", "manage_mm_goals"=>"1", "manage_mm_tasks"=>"0", "manage_mm_messages"=>"0", "manage_mm_meetings"=>"0"}
    permissions = { "admin" => admin, "users" => users, goal_progress_type: MentoringModel::GoalProgressType::MANUAL }
    mentoring_model_params = { "allow_due_date_edit" => true, "allow_messaging" => true, "allow_forum" => false }

    login_as_super_user
    post :create_template_objects, params: { id: @mentoring_model.id, permissions: permissions, mentoring_model: mentoring_model_params}

    assert_equal MentoringModel::GoalProgressType::MANUAL, @mentoring_model.reload.goal_progress_type
  end

  def test_cannot_disable_forum_when_published_groups_exist
    @mentoring_model.update_attributes(allow_messaging: false, allow_forum: true)
    group = groups(:mygroup)
    group.update_attribute(:mentoring_model_id, @mentoring_model.id)
    group.terminate!(users(:f_admin), "Reason", group.program.permitted_closure_reasons.first.id)
    assert_false @mentoring_model.can_disable_forum?
    mentoring_model_params = { "allow_messaging" => false, "allow_forum" => false }

    login_as_super_user
    MentoringModel.any_instance.expects(:can_update_features?).never
    assert_no_difference("@mentoring_model.object_role_permissions.count") do
      post :create_template_objects, params: { id: @mentoring_model.id, mentoring_model: mentoring_model_params}
    end
    assert_redirected_to setup_mentoring_model_path(@mentoring_model)
    assert_equal "There are ongoing/closed mentoring connections using this mentoring connection template. Clone this template to create a new template or remove all the ongoing/closed mentoring connections to disable discussion boards.", flash[:error]
  end

  def test_index_when_milestone_template_permission_enabled
    admin_role = programs(:albers).roles.with_name(RoleConstants::ADMIN_NAME)
    @mentoring_model.allow_manage_mm_milestones!(admin_role)
    milestone_template1 = create_mentoring_model_milestone_template
    milestone_template2 = create_mentoring_model_milestone_template(title: "Carrie", description: "We can't get hit again")
    task_template_1 = create_mentoring_model_task_template(milestone_template_id: milestone_template1.id)
    task_template_2 = create_mentoring_model_task_template(milestone_template_id: milestone_template2.id)
    assert_equal 1, milestone_template1.mentoring_model_task_templates.size
    assert_equal 1, milestone_template2.mentoring_model_task_templates.size

    get :show, params: { id: @mentoring_model.id}
    assert_response :success
    assert_equal [milestone_template1.id, milestone_template2.id], assigns(:mentoring_model_task_templates).keys
    assert_equal [task_template_1, task_template_2], assigns(:mentoring_model_task_templates).values.flatten
  end

  def test_make_default
    latest_mentoring_model = create_mentoring_model
    assert @mentoring_model.default?
    assert_false latest_mentoring_model.default?

    post :make_default, xhr: true, params: { id: latest_mentoring_model.id}
    assert_response :success

    assert_false @mentoring_model.reload.default?
    assert latest_mentoring_model.reload.default?
  end

  def test_make_default_when_already_default
    assert @mentoring_model.default?

    post :make_default, xhr: true, params: { id: @mentoring_model.id}
    assert_response :success
    assert @mentoring_model.reload.default?
  end

  def test_destroy_default_mentoring_model
    assert_permission_denied do
      delete :destroy, xhr: true, params: { id: @mentoring_model.id}
    end
  end

  def test_destroy_already_applied_model
    latest_mentoring_model = create_mentoring_model
    group = groups(:mygroup)
    group.update_attributes!(mentoring_model_id: latest_mentoring_model.id)
    latest_mentoring_model.reload

    assert_permission_denied do
      delete :destroy, xhr: true, params: { id: latest_mentoring_model.id}
    end
  end

  def test_destroy_mentoring_model_with_draft_groups
    latest_mentoring_model = create_mentoring_model
    group = programs(:albers).groups.drafted.first
    group.update_attributes!(mentoring_model_id: latest_mentoring_model.id, status: Group::Status::DRAFTED)
    assert_equal latest_mentoring_model, group.reload.mentoring_model

    assert_difference "MentoringModel.count", -1 do
      delete :destroy, xhr: true, params: { id: latest_mentoring_model.id}
    end
    assert_response :success
    assert_equal "{\"drafted_groups_text\":\"1 Drafted &raquo;\",\"mentoring_model_id\":1,\"from_view\":false}", response.body

    assert_equal @mentoring_model, group.reload.mentoring_model
  end

  def test_destroy_success
    program = programs(:albers)
    mentoring_model1 = create_mentoring_model
    mentoring_model2 = create_mentoring_model(title: "Random Template")
    assert_equal 3, program.reload.mentoring_models.count

    assert_difference "MentoringModel.count", -1 do
      delete :destroy, xhr: true, params: { id: mentoring_model2.id}
    end
    assert_response :success
    assert_equal "{\"drafted_groups_text\":\"0 Drafted &raquo;\",\"mentoring_model_id\":1,\"from_view\":false}", response.body

    assert_equal 2, program.reload.mentoring_models.count
    assert_equal [@mentoring_model, mentoring_model1], program.mentoring_models
  end

  def test_destroy_success_from_view_page
    program = programs(:albers)
    mentoring_model1 = create_mentoring_model
    mentoring_model2 = create_mentoring_model(title: "Random Template")
    assert_equal 3, program.reload.mentoring_models.count

    assert_difference "MentoringModel.count", -1 do
      delete :destroy, xhr: true, params: { id: mentoring_model2.id, from_view: true}
    end
    assert_equal "The Mentoring Connection Plan Template has been deleted successfully.", flash[:notice]
    assert_equal "{\"redirect_url\":\"/p/albers/mentoring_models\",\"from_view\":true}", response.body

    assert_equal 2, program.reload.mentoring_models.count
    assert_equal [@mentoring_model, mentoring_model1], program.mentoring_models
  end

  def test_export_csv_only_for_admin
    MentoringModel.any_instance.stubs(:title).returns("file, name with comma")
    Time.expects(:zone).at_least(0).returns(ActiveSupport::TimeZone.new("Alaska"))
    get :export_csv, params: { id: @mentoring_model.id}
    assert_response :success
    assert_equal "text/csv; charset=iso-8859-1; header=present", @response.headers["Content-Type"]
    date = DateTime.localize(Time.current, format: :csv_timestamp)
    assert_equal "attachment; filename=file__name_with_comma_Template_#{date}.csv", @response.headers["Content-Disposition"]
  end

  def test_export_csv_failure
    current_user_is :f_mentor
    assert_permission_denied do
      get :export_csv, params: { id: @mentoring_model.id}
    end
  end

  def test_view_success
    get :view, params: { id: @mentoring_model.id, from_mentoring_models: true}
    assert_response :success
    assert assigns(:read_only)
    assert assigns(:no_wizard_view)
    assert_equal ({:label => "Mentoring Connection Plan Templates", :link => mentoring_models_path}), assigns(:back_link)
  end

  def test_update_duration_success
    assert_equal 180, @mentoring_model.mentoring_period_value
    assert_equal MentoringPeriodUtils::MentoringPeriodUnit::DAYS, @mentoring_model.mentoring_period_unit

    put :update_duration, params: { id: @mentoring_model.id, mentoring_model: {mentoring_period_unit: MentoringPeriodUtils::MentoringPeriodUnit::DAYS.to_s, mentoring_period_value: "34"}}, format: :js
    assert_response :success
    assert_equal 34, @mentoring_model.reload.mentoring_period_value
    assert_equal MentoringPeriodUtils::MentoringPeriodUnit::DAYS, @mentoring_model.mentoring_period_unit
  end

  def test_update_duration_with_ongoing_connection
    @mentoring_model.program.groups[0].update_attribute(:mentoring_model_id, @mentoring_model.id)
    assert_false @mentoring_model.reload.can_update_duration?

    assert_permission_denied do
      put :update_duration, params: { id: @mentoring_model.id, mentoring_model: {mentoring_period_unit: MentoringPeriodUtils::MentoringPeriodUnit::DAYS.to_s, mentoring_period_value: "34"}}, format: :js
    end
  end

  def test_duplicate_new_success
    get :duplicate_new, xhr: true, params: { id: @mentoring_model.id}
    assert_response :success
    assert_equal [@mentoring_model.title.downcase], assigns(:mentoring_model_titles)
  end

  def test_new_redirected_to_super_login
    get :new
    assert_redirected_to super_login_path
  end

  def test_duplicate_create_success
    assert_difference "MentoringModel.count" do
      post :duplicate_create, params: { id: @mentoring_model.id, mentoring_model: {title: "House Of Cards"}}
    end
    assert_redirected_to edit_mentoring_model_path(assigns(:new_mentoring_model))
    assert_equal "House Of Cards", assigns(:new_mentoring_model).title
  end

  def test_new_success
    mentoring_model = create_mentoring_model(title: "House of Cards")

    login_as_super_user
    get :new
    assert_response :success
    assert_equal [programs(:albers).default_mentoring_model.title, mentoring_model.title].collect(&:downcase), assigns(:mentoring_model_titles)
    assert_false assigns(:mentoring_model).default?
  end

  def test_new_hybrid_success
    programs(:albers).update_attribute(:hybrid_templates_enabled, true)

    login_as_super_user
    get :new, params: { hybrid: true}
    assert_response :success
    assert_template partial: "_hybrid_form"
    assert assigns(:mentoring_model).hybrid?
  end

  def test_create_hybrid
    program = programs(:albers)
    program.update_attribute(:hybrid_templates_enabled, true)
    create_mentoring_model(title: "Template 2")
    child_ids = program.reload.mentoring_models.map(&:id)

    login_as_super_user
    assert_difference "MentoringModel.count" do
      post :create, params: { mentoring_model: {
        title: "title",
        description: "desc",
        mentoring_model_type: "hybrid",
        mentoring_period_value: 6,
        mentoring_period_unit: MentoringPeriodUtils::MentoringPeriodUnit::WEEKS,
        child_ids: child_ids
      }}
    end
    assert_redirected_to view_mentoring_model_path(assigns(:mentoring_model), from_mentoring_models: true)
    assert_equal "title", assigns(:mentoring_model).title
    assert_equal "desc", assigns(:mentoring_model).description
    assert assigns(:mentoring_model).hybrid?
    assert_equal assigns(:mentoring_model).goal_progress_type, program.mentoring_models.first.goal_progress_type
    assert_equal 6.weeks.to_i, assigns(:mentoring_model).mentoring_period
    assert_equal ["Albers Mentor Program Template", "Template 2"], assigns(:mentoring_model).children.map(&:title)
  end

  def test_create_hybrid_progress_type
    program = programs(:albers)
    program.update_attribute(:hybrid_templates_enabled, true)
    create_mentoring_model(title: "Template 2")
    program.reload.mentoring_models.update_all(goal_progress_type: MentoringModel::GoalProgressType::MANUAL)
    child_ids = program.reload.mentoring_models.map(&:id)

    login_as_super_user
    assert_difference "MentoringModel.count" do
      post :create, params: { mentoring_model: {
        title: "title",
        description: "desc",
        mentoring_model_type: "hybrid",
        mentoring_period_value: 6,
        mentoring_period_unit: MentoringPeriodUtils::MentoringPeriodUnit::DAYS,
        child_ids: child_ids
      }}
    end
    assert_redirected_to view_mentoring_model_path(assigns(:mentoring_model), from_mentoring_models: true)
    assert_equal "title", assigns(:mentoring_model).title
    assert_equal "desc", assigns(:mentoring_model).description
    assert assigns(:mentoring_model).hybrid?
    assert_equal assigns(:mentoring_model).goal_progress_type, program.mentoring_models.first.goal_progress_type
    assert_equal 6.days.to_i, assigns(:mentoring_model).mentoring_period
    assert_equal ["Albers Mentor Program Template", "Template 2"], assigns(:mentoring_model).children.map(&:title)
  end

  def test_edit_hybrid
    programs(:albers).update_attribute(:hybrid_templates_enabled, true)
    hybrid_model = create_mentoring_model(title: "Hybrid title", description: "Hybrid desc", mentoring_model_type: MentoringModel::Type::HYBRID)

    login_as_super_user
    get :edit, params: { id: hybrid_model.id}
    assert_response :success
    assert_template "_hybrid_form"
    assert assigns(:mentoring_model).hybrid?
  end

  def test_setup_hybrid_renders_edit
    programs(:albers).update_attribute(:hybrid_templates_enabled, true)
    hybrid_model = create_mentoring_model(title: "Hybrid title", description: "Hybrid desc", mentoring_model_type: MentoringModel::Type::HYBRID)

    login_as_super_user
    get :setup, params: { id: hybrid_model.id}
    assert_response :success
    assert_template "_hybrid_form"
    assert assigns(:mentoring_model).hybrid?
  end

  def test_show_hybrid_renders_edit
    programs(:albers).update_attribute(:hybrid_templates_enabled, true)
    hybrid_model = create_mentoring_model(title: "Hybrid title", description: "Hybrid desc", mentoring_model_type: MentoringModel::Type::HYBRID)

    login_as_super_user
    get :show, params: { id: hybrid_model.id}
    assert_response :success
    assert_template "_hybrid_form"
    assert assigns(:mentoring_model).hybrid?
  end

  def test_update_hybrid
    program = programs(:albers)
    program.update_attribute(:hybrid_templates_enabled, true)
    create_mentoring_model(title: "Template 2")
    child_ids = program.reload.mentoring_models.map(&:id)
    hybrid_model = create_mentoring_model(title: "Hybrid title", description: "Hybrid desc", mentoring_model_type: MentoringModel::Type::HYBRID)

    login_as_super_user
    assert_no_difference "MentoringModel.count" do
      put :update, params: { id: hybrid_model.id, mentoring_model: {
        title: "title",
        description: "desc",
        mentoring_model_type: "hybrid",
        mentoring_period_value: 5,
        mentoring_period_unit: MentoringPeriodUtils::MentoringPeriodUnit::DAYS,
        child_ids: child_ids[0..0]
      }}
    end
    assert_redirected_to view_mentoring_model_path(assigns(:mentoring_model), from_mentoring_models: true)
    assert_equal "title", assigns(:mentoring_model).title
    assert_equal "desc", assigns(:mentoring_model).description
    assert assigns(:mentoring_model).hybrid?
    assert_equal 5.days.to_i, assigns(:mentoring_model).mentoring_period
    assert_equal ["Albers Mentor Program Template"], assigns(:mentoring_model).children.map(&:title)
  end

  def test_create_success
    login_as_super_user
    assert_difference "MentoringModel.count" do
      post :create, params: { mentoring_model: { title: "House of Cards", description: "Frank Underwood" }, set_up_and_continue_later: "true"}
    end
    assert_redirected_to mentoring_models_path
    assert_equal "House of Cards", assigns(:mentoring_model).title
    assert_equal "Frank Underwood", assigns(:mentoring_model).description
  end

  def test_create_success_reditrecto_step2
    login_as_super_user
    assert_difference "MentoringModel.count" do
      post :create, params: { mentoring_model: {title: "House of Cards", description: "Frank Underwood"}}
    end
    assert_redirected_to setup_mentoring_model_path(assigns(:mentoring_model))
    assert_equal "House of Cards", assigns(:mentoring_model).title
    assert_equal "Frank Underwood", assigns(:mentoring_model).description
  end

  def test_edit_success
    mentoring_model = create_mentoring_model(title: "House of Cards")

    get :edit, params: { id: @mentoring_model.id}
    assert_response :success
    assert_equal [mentoring_model.title.downcase], assigns(:mentoring_model_titles)
    assert assigns(:mentoring_model).default?
  end

  def test_update_success
    assert_no_difference "MentoringModel.count" do
      post :update, params: { id: @mentoring_model.id, mentoring_model: {title: "House of Cards", description: "Frank Underwood"}, set_up_and_continue_later: "true"}
    end
    assert_redirected_to mentoring_models_path
    assert_equal "House of Cards", assigns(:mentoring_model).title
    assert_equal "Frank Underwood", assigns(:mentoring_model).description
  end

  def test_update_success_redirect_to_step2
    login_as_super_user
    assert_no_difference "MentoringModel.count" do
      post :update, params: { id: @mentoring_model.id, mentoring_model: {title: "House of Cards", description: "Frank Underwood"}}
    end
    assert_redirected_to setup_mentoring_model_path(assigns(:mentoring_model))
    assert_equal "House of Cards", assigns(:mentoring_model).title
    assert_equal "Frank Underwood", assigns(:mentoring_model).description
  end

  def test_update_success_redirect_to_step3
    assert_no_difference "MentoringModel.count" do
      post :update, params: { id: @mentoring_model.id, mentoring_model: {title: "House of Cards", description: "Frank Underwood"}}
    end
    assert_redirected_to mentoring_model_path(assigns(:mentoring_model))
    assert_equal "House of Cards", assigns(:mentoring_model).title
    assert_equal "Frank Underwood", assigns(:mentoring_model).description
  end

  def test_setup_with_wizard_view
    login_as_super_user
    get :setup, params: { id: @mentoring_model.id}
    assert_response :success
    assert_page_title "#{@mentoring_model.title}"
    assert_select "div#enable_features" do
      assert_select ".cjs_features_list", count: 3
    end
  end

  def test_no_access_for_program_with_disabled_ongoing_mentoring
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_permission_denied do
      get :index
    end
  end

  def test_fetch_tasks_for_profile_when_group_is_not_pending
    current_user_is :f_admin_pbe
    current_program_is :pbe
    p = programs(:pbe)
    assert_permission_denied do
      get :fetch_tasks, xhr: true, params: { id: p.groups.published.first.mentoring_model_id, :group_id => p.groups.published.first.id}
    end
  end

  def test_fetch_tasks_for_profile_permissions_for_global_group
    current_user_is :f_mentor_pbe
    current_program_is :pbe
    p = programs(:pbe)
    g = p.groups.pending.first
    mentoring_model = g.mentoring_model
    mentoring_model.mentoring_model_milestone_templates.create!(title: "title", description: "description")

    get :fetch_tasks, xhr: true, params: { id: g.mentoring_model_id, :group_id => g.id, :milestone_template_id => mentoring_model.mentoring_model_milestone_templates.first.id}

    assert_response :success
    assert_false users(:f_mentor_pbe).is_admin?
    assert_false g.has_member?(users(:f_mentor_pbe))
    assert g.global?
  end

  def test_fetch_tasks_for_profile_permissions_for_admin_user
    current_user_is :f_admin_pbe
    current_program_is :pbe
    p = programs(:pbe)
    g = p.groups.pending.first
    g.update_attribute(:global, false)
    mentoring_model = g.mentoring_model
    mentoring_model.mentoring_model_milestone_templates.create!(title: "title", description: "description")

    get :fetch_tasks, xhr: true, params: { id: g.mentoring_model_id, :group_id => g.id, :milestone_template_id => mentoring_model.mentoring_model_milestone_templates.first.id}

    assert_response :success
    assert users(:f_admin_pbe).is_admin?
    assert_false g.has_member?(users(:f_mentor_pbe))
    assert_false g.global?
  end

  def test_fetch_tasks_for_profile_permissions_for_group_member
    current_user_is :pbe_mentor_0
    current_program_is :pbe
    p = programs(:pbe)
    g = p.groups.pending.first
    g.update_attribute(:global, false)
    mentoring_model = g.mentoring_model
    milestone_template = mentoring_model.mentoring_model_milestone_templates.create!(title: "title", description: "description")

    task_template = mentoring_model.mentoring_model_task_templates.create!({
      milestone_template_id: milestone_template.id,
      required: true,
      title: "title",
      description: "description",
      duration: 10,
      action_item_type: MentoringModel::TaskTemplate::ActionItem::DEFAULT,
      role_id: p.roles.first.id
    })

    get :fetch_tasks, xhr: true, params: { id: g.mentoring_model_id, :group_id => g.id, :milestone_template_id => milestone_template.id}

    assert_response :success
    assert_false users(:pbe_mentor_0).is_admin?
    assert g.has_member?(users(:pbe_mentor_0))
    assert_false g.global?
    assert_equal assigns(:milestone), milestone_template
    assert_equal assigns(:milestone_items), [task_template]
  end

  def test_fetch_tasks_for_profile_permissions
    current_user_is :pbe_mentor_1
    current_program_is :pbe
    p = programs(:pbe)
    g = p.groups.pending.first
    g.update_attribute(:global, false)
    mentoring_model = g.mentoring_model
    mentoring_model.mentoring_model_milestone_templates.create!(title: "title", description: "description")

    assert_permission_denied do
      get :fetch_tasks, xhr: true, params: { id: mentoring_model.id, group_id: g.id, milestone_template_id: mentoring_model.mentoring_model_milestone_templates.first.id }
    end
    assert_false users(:pbe_mentor_1).is_admin?
    assert_false g.has_member?(users(:pbe_mentor_1))
    assert_false g.global?
  end

  def test_fetch_tasks_for_preview
    current_user_is :f_mentor_pbe
    current_program_is :pbe
    p = programs(:pbe)
    mentoring_model = p.mentoring_models.first
    mentoring_model.mentoring_model_milestone_templates.create!(title: "title", description: "description")

    assert_no_difference "Group.count" do
      get :fetch_tasks, xhr: true, params: { id: mentoring_model.id, :milestone_template_id => mentoring_model.mentoring_model_milestone_templates.first.id, preview: "true"}
    end
    assert_response :success
  end

  def test_preview
    mentoring_model = mentoring_models(:mentoring_models_1)

    assert_no_difference "Group.count" do
      get :preview, params: { id: mentoring_model.id}
    end
    assert_nil assigns[:group].id
    assert_equal assigns[:mentoring_model].id, mentoring_model.id
    assert_equal assigns[:milestones], mentoring_model.mentoring_model_milestone_templates
    assert_raise(Exception) do
      assigns[:group].save
    end
  end

  def test_check_access_to_show_tasks_in_preview
    @controller.params[:preview] = "true"
    assert @controller.send(:check_access_to_show_tasks_in_preview)
  end
end