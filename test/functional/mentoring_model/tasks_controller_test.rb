require_relative './../../test_helper.rb'

class MentoringModel::TasksControllerTest < ActionController::TestCase
  def setup
    super
    current_user_is :f_mentor
    @program = programs(:albers)
    @program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    @group = groups(:mygroup)
    @group.mentoring_model = @group.program.mentoring_models.first
    @group.save!
    @group.allow_manage_mm_tasks!(@program.get_role(RoleConstants::MENTOR_NAME))
    @user = users(:f_mentor)
    @task = create_mentoring_model_task
  end

  def test_new
    get :new, xhr: true, params: { group_id: @group.id}
    assert_response :success
    assert_template 'new'
    assert_equal @group, assigns(:group)
    assert_not_nil assigns(:task)
    assert_equal @group, assigns(:task).group
    assert_match /MentoringModelTask.addForm\(\".cjs-action-item-response-container/, response.body
  end

  def test_new_with_milestones_success
    @group.allow_manage_mm_milestones!(@program.get_role(RoleConstants::MENTOR_NAME))
    milestone = create_mentoring_model_milestone

    get :new, xhr: true, params: { group_id: @group.id, milestone_id: milestone.id}
    assert_response :success

    assert_equal milestone, assigns(:milestone)
    assert_match /MentoringModelMilestones.addForm\(\"#{milestone.id}\"/, response.body
  end

  def test_new_with_task_sections
    @group.allow_manage_mm_milestones!(@program.get_role(RoleConstants::MENTOR_NAME))
    milestone = create_mentoring_model_milestone

    get :new, xhr: true, params: { group_id: @group.id, task_section_id: MentoringModel::Task::Section::REMAINING}
    assert_response :success

    assert_match /MentoringModelTask.addForm\(\"#cjs_add_section_task_#{MentoringModel::Task::Section::REMAINING} .cjs-action-item-response-container/, response.body
  end

  def test_new_with_milestones_permission_denied
    assert_permission_denied do
      get :new, xhr: true, params: { group_id: @group.id, milestone_id: 1}
    end
  end

  def test_fetch_goals_for_new_action_with_goals_enabled_at_end_users
    mmg1 = create_mentoring_model_goal
    mmg2 = create_mentoring_model_goal
    create_object_role_permission("manage_mm_goals", role: "users", object: @group)
    get :new, xhr: true, params: { group_id: @group.id}
    assert_equal [mmg1, mmg2], assigns(:goals_to_associate)
  end

  def test_no_fetch_goals_for_manual_type
    mmg1 = create_mentoring_model_goal
    mmg2 = create_mentoring_model_goal
    mmg1.group.mentoring_model.update_attribute(:goal_progress_type, MentoringModel::GoalProgressType::MANUAL)
    create_object_role_permission("manage_mm_goals", role: "users", object: @group)
    get :new, xhr: true, params: { group_id: @group.id}
    assert_nil assigns(:goals_to_associate)
  end

  def test_fetch_goals_for_new_action_with_goals_disabled_at_end_users_and_enabled_at_admin_level
    mmg1 = create_mentoring_model_goal
    mmg2 = create_mentoring_model_goal
    create_object_role_permission("manage_mm_goals", role: "admin", object: @group)
    get :new, xhr: true, params: { group_id: @group.id}
    assert_equal [mmg1, mmg2], assigns(:goals_to_associate)
  end

  def test_create
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_TASK).once
    assert_difference "MentoringModel::Task.count", 1 do
      post :create, xhr: true, params: { group_id: @group.id, mentoring_model_task: {
        connection_membership_id: Connection::Membership.where(group_id: @group.id, user_id: @user.id)[0].id,
        required: false,
        title: "some task title",
        description: "some task desc",
        status: MentoringModel::Task::Status::TODO
      }}
    end
    assert_response :success
    assert_equal "some task title", assigns(:task).title
    assert_equal "some task desc", assigns(:task).description
    assert_false assigns(:task).required?
    assert_nil assigns(:task).mentoring_model_task_template
    assert_false assigns(:task).unassigned_from_template?
  end

  def test_create_only_one_for_multiple_member_group
    group = groups(:multi_group)
    program = group.program
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    group.allow_manage_mm_tasks!(program.get_role(RoleConstants::MENTOR_NAME))
    user = group.mentor_memberships.first.user
    current_user_is user
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_TASK).once
    assert_difference "MentoringModel::Task.count", 1 do
      post :create, xhr: true, params: { group_id: group.id, mentoring_model_task: {
        connection_membership_id: Connection::Membership.find_by(group_id: group.id, user_id: user.id).id,
        required: false,
        title: "some task title",
        description: "some task desc",
        status: MentoringModel::Task::Status::TODO
      }}
    end
    assert_response :success
    assert_equal "some task title", assigns(:task).title
    assert_equal "some task desc", assigns(:task).description
    assert_false assigns(:task).required?
    assert_nil assigns(:task).mentoring_model_task_template
    assert_false assigns(:task).unassigned_from_template?
  end

  def test_create_only_for_one_role
    group = groups(:multi_group)
    program = group.program
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    group.allow_manage_mm_tasks!(program.get_role(RoleConstants::MENTOR_NAME))
    user = group.mentor_memberships.first.user
    current_user_is user
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_TASK).once
    assert_difference "MentoringModel::Task.count", group.mentor_memberships.count do
      post :create, xhr: true, params: { group_id: group.id, mentoring_model_task: {
        connection_membership_id: "#{MentoringModel::TasksHelper::FOR_ALL_ROLE_ID}#{group.program.roles.find_by(name: RoleConstants::MENTOR_NAME).id}",
        required: false,
        title: "some task title",
        description: "some task desc",
        status: MentoringModel::Task::Status::TODO
      }}
    end
    assert_response :success
    group_mentor_members = group.mentor_memberships.map(&:user)
    assigns(:created_tasks).each do |task|
      assert_equal "some task title", task.title
      assert_equal "some task desc", task.description
      assert_false task.required?
      assert_nil task.mentoring_model_task_template
      assert_false task.unassigned_from_template?
      assert group_mentor_members.include?(task.user)
      group_mentor_members -= [task.user]
    end
    assert group_mentor_members.empty?
  end

  def test_create_for_all
    group = groups(:multi_group)
    program = group.program
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    group.allow_manage_mm_tasks!(program.get_role(RoleConstants::MENTOR_NAME))
    user = group.mentor_memberships.first.user
    current_user_is user
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_TASK).once
    assert_difference "MentoringModel::Task.count", group.memberships.count do
      post :create, xhr: true, params: { group_id: group.id, mentoring_model_task: {
        connection_membership_id: MentoringModel::TasksHelper::FOR_ALL_USERS,
        required: false,
        title: "some task title",
        description: "some task desc",
        status: MentoringModel::Task::Status::TODO
      }}
    end
    assert_response :success
    group_members = group.memberships.map(&:user)
    assigns(:created_tasks).each do |task|
      assert_equal "some task title", task.title
      assert_equal "some task desc", task.description
      assert_false task.required?
      assert_nil task.mentoring_model_task_template
      assert_false task.unassigned_from_template?
      assert group_members.include?(task.user)
      group_members -= [task.user]
    end
    assert group_members.empty?
  end

  def test_pending_notifications_gets_deleted_on_deleting_the_task
    current_user_is :f_mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_TASK).once
    assert_difference "PendingNotification.count", 1 do
      post :create, xhr: true, params: { group_id: @group.id, mentoring_model_task: {
        connection_membership_id: Connection::Membership.where(group_id: @group.id, user_id: users(:mkr_student).id)[0].id,
        required: false,
        title: "some task title",
        description: "some task desc",
        status: MentoringModel::Task::Status::TODO
      }}
    end
    task = MentoringModel::Task.last
    assert_difference "PendingNotification.count", -1 do
      task.destroy
    end
  end

  def test_create_with_vulnerable_content_with_version_v1
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v1")
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_TASK).once
    assert_no_difference "VulnerableContentLog.count" do
      assert_difference "MentoringModel::Task.count", 1 do
        post :create, xhr: true, params: { group_id: @group.id, mentoring_model_task: {
          connection_membership_id: Connection::Membership.where(group_id: @group.id, user_id: @user.id)[0].id,
          required: false,
          title: "some task title",
          description: "some task desc<script>alert(10);</script>",
          status: MentoringModel::Task::Status::TODO
        }}
      end
    end
  end

  def test_create_with_vulnerable_content_with_version_v2
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v2")
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_TASK).once
    assert_difference "VulnerableContentLog.count" do
      assert_difference "MentoringModel::Task.count" do
        post :create, xhr: true, params: { group_id: @group.id, mentoring_model_task: {
          connection_membership_id: Connection::Membership.where(group_id: @group.id, user_id: @user.id)[0].id,
          required: false,
          title: "some task title",
          description: "some task desc<script>alert(10);</script>",
          status: MentoringModel::Task::Status::TODO
        }}
      end
    end
    assert_equal MentoringModel::Task.last.description, "some task descalert(10);"
  end

  def test_create_with_goal_for_non_required_task
    mmg1 = create_mentoring_model_goal
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_TASK).once
    assert_difference "MentoringModel::Task.count", 1 do
      post :create, xhr: true, params: { group_id: @group.id, mentoring_model_task: {
        connection_membership_id: Connection::Membership.where(group_id: @group.id, user_id: @user.id)[0].id,
        required: false,
        title: "some task title",
        description: "some task desc",
        status: MentoringModel::Task::Status::TODO,
        goal_id: mmg1.id
      }}
    end
    assert_response :success
    assert_equal "some task title", assigns(:task).title
    assert_equal "some task desc", assigns(:task).description
    assert_false assigns(:task).required?
    assert_nil assigns(:task).mentoring_model_goal
    assert_false assigns(:task).unassigned_from_template?
  end

  def test_create_with_goal_for_required_task
    mmg1 = create_mentoring_model_goal
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_TASK).once
    assert_difference "MentoringModel::Task.count", 1 do
      post :create, xhr: true, params: { group_id: @group.id, mentoring_model_task: {
        connection_membership_id: Connection::Membership.where(group_id: @group.id, user_id: @user.id)[0].id,
        required: true,
        due_date: DateTime.localize(Time.new(2001), format: :full_display_no_time),
        title: "some task title",
        description: "some task desc",
        status: MentoringModel::Task::Status::TODO,
        goal_id: mmg1.id
      }}
    end
    assert_response :success
    assert_equal "some task title", assigns(:task).title
    assert_equal "some task desc", assigns(:task).description
    assert assigns(:task).required?
    assert_equal mmg1, assigns(:task).mentoring_model_goal
  end

  def test_create_with_goal_for_required_task_with_target_user
    mmg1 = create_mentoring_model_goal
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_TASK).once
    assert_difference "MentoringModel::Task.count", 1 do
      post :create, xhr: true, params: { group_id: @group.id, mentoring_model_task: {
        connection_membership_id: Connection::Membership.where(group_id: @group.id, user_id: @user.id)[0].id,
        required: true,
        due_date: DateTime.localize(Time.new(2001), format: :full_display_no_time),
        title: "some task title",
        description: "some task desc",
        status: MentoringModel::Task::Status::TODO,
        goal_id: mmg1.id,
      }, target_user_id: @user.id, target_user_type: GroupsController::TargetUserType::INDIVIDUAL}
    end
    assert_response :success
    assert_equal "some task title", assigns(:task).title
    assert_equal "some task desc", assigns(:task).description
    assert assigns(:task).required?
    assert_equal @group.reload.mentoring_model_tasks.where(:connection_membership_id => @user.connection_memberships), assigns(:all_tasks).select{|task| task.class == MentoringModel::Task}
    assert_equal mmg1, assigns(:task).mentoring_model_goal
  end

  def test_fetch_associated_goal_and_tasks_with_create
    @group.allow_manage_mm_goals!(@program.roles.for_mentoring_models)
    mmg1 = create_mentoring_model_goal(group_id: @group.id)
    mmt1 = create_mentoring_model_task(group_id: @group.id, goal_id: mmg1.id, required: true)
    mmt2 = create_mentoring_model_task(group_id: @group.id, goal_id: mmg1.id, required: false)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_TASK).once
    post :create, xhr: true, params: { group_id: @group.id, mentoring_model_task: {
      connection_membership_id: Connection::Membership.where(group_id: @group.id, user_id: @user.id)[0].id,
      required: true,
      due_date: DateTime.localize(Time.new(2001), format: :full_display_no_time),
      title: "some task title",
      description: "some task desc",
      status: MentoringModel::Task::Status::TODO,
      goal_id: mmg1.id
    }}

    assert_response :success
    assert assigns(:task).required?
    assert_equal mmg1, assigns(:associated_goal)
    assert_equal 2, assigns(:required_tasks).count
  end


  def test_sends_email_after_new_task_assigned
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_TASK).once
    assert_difference "PendingNotification.all.size", 1 do
      post :create, xhr: true, params: { group_id: @group.id, mentoring_model_task: {
        connection_membership_id: Connection::Membership.where(group_id: @group.id, user_id: users(:mkr_student).id)[0].id,
        required: false,
        title: "some task title",
        description: "some task desc",
        status: MentoringModel::Task::Status::TODO
      }}
    end
    pn = PendingNotification.last
    assert_equal RecentActivityConstants::Type::MENTORING_MODEL_TASK_CREATION, pn.action_type
    assert_equal MentoringModel::Task.name, pn.ref_obj_type
    assert_equal MentoringModel::Task.last.id, pn.ref_obj_id
  end

  def test_create_update_positions
    t1 = create_mentoring_model_task(due_date: Time.new(2000), required: true)
    t2 = create_mentoring_model_task(due_date: Time.new(2002), required: true)
    t3 = create_mentoring_model_task(due_date: Time.new(2003), required: true)
    MentoringModel::Task.update_positions(@group.reload.mentoring_model_tasks, t1)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_TASK).once
    post :create, xhr: true, params: { group_id: @group.id, mentoring_model_task: {
      connection_membership_id: Connection::Membership.where(group_id: @group.id, user_id: @user.id)[0].id,
      required: true,
      title: "some task title",
      description: "some task desc",
      status: MentoringModel::Task::Status::TODO,
      due_date: DateTime.localize(Time.new(2001), format: :full_display_no_time)
    }}
    t4 = MentoringModel::Task.last
    assert_equal [1, 3, 4, 2],  [t1, t2, t3, t4].collect(&:reload).map(&:position)
  end

  def test_edit
    get :edit, xhr: true, params: { group_id: @group.id, id: @task.id}
    assert_response :success
    assert_template 'edit'
    assert_equal @task, assigns(:task)
  end
  
  def test_should_fetch_tasks_for_complete_section
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    current_user_is :f_mentor
    t1 = create_mentoring_model_task(required: true, due_date: 1.week.ago.utc, status: MentoringModel::Task::Status::DONE)
    t2 = create_mentoring_model_task(required: true, due_date: 3.days.from_now.utc)
    t3 = create_mentoring_model_task(required: true, due_date: 16.days.from_now.utc)
    m1 ={"current_occurrence_time"=>@group.meetings.first.occurrences.first.start_time, "meeting"=>@group.meetings.first}

    get :fetch_section_tasks, xhr: true, params: { :group_id => @group.id, target_user_id: users(:f_mentor).id, target_user_type: GroupsController::TargetUserType::INDIVIDUAL, section_type: MentoringModel::Task::Section::COMPLETE.to_s, list_id: "#dummy_link"}
    assert_response :success
    assert_equal true, assigns(:surveys_controls_allowed)
    assert_equal [t1], assigns(:section_tasks)
    assert_equal "#dummy_link", assigns(:list_id)
    assert_false assigns(:zero_upcoming_tasks)
    assert_equal users(:f_mentor), assigns(:target_user)
    assert_equal GroupsController::TargetUserType::INDIVIDUAL, assigns(:target_user_type)
  end

  def test_should_fetch_tasks_for_complete_section_by_admin
    current_user_is :f_admin
    get :fetch_section_tasks, xhr: true, params: { :group_id => @group.id, target_user_id: users(:f_mentor).id, target_user_type: GroupsController::TargetUserType::INDIVIDUAL, section_type: MentoringModel::Task::Section::COMPLETE.to_s, list_id: "#dummy_link"}
    assert_response :success
    assert_equal false, assigns(:surveys_controls_allowed)
    assert_equal "#dummy_link", assigns(:list_id)
    assert_false assigns(:zero_upcoming_tasks)
    assert_equal users(:f_mentor), assigns(:target_user)
    assert_equal GroupsController::TargetUserType::INDIVIDUAL, assigns(:target_user_type)
  end

  def test_should_fetch_tasks_for_overdue_section
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    current_user_is :f_mentor
    t1 = create_mentoring_model_task(required: true, due_date: 1.week.ago.utc)
    t2 = create_mentoring_model_task(required: true, due_date: 3.days.from_now.utc)
    t3 = create_mentoring_model_task(required: true, due_date: 16.days.from_now.utc)

    get :fetch_section_tasks, xhr: true, params: { :group_id => @group.id, target_user_id: users(:f_mentor).id, target_user_type: GroupsController::TargetUserType::INDIVIDUAL, section_type: MentoringModel::Task::Section::OVERDUE.to_s, list_id: "#dummy_link"}
    assert_response :success
    assert_equal_unordered [t1], assigns(:section_tasks)
    assert_equal "#dummy_link", assigns(:list_id)
    assert_false assigns(:zero_upcoming_tasks)
    assert_equal users(:f_mentor), assigns(:target_user)
    assert_equal GroupsController::TargetUserType::INDIVIDUAL, assigns(:target_user_type)
  end

  def test_should_fetch_tasks_for_upcoming_section
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    current_user_is :f_mentor
    t1 = create_mentoring_model_task(required: true, due_date: 1.week.ago.utc)
    t2 = create_mentoring_model_task(required: true, due_date: 3.days.from_now.utc)
    t3 = create_mentoring_model_task(required: true, due_date: 16.days.from_now.utc)

    get :fetch_section_tasks, xhr: true, params: { :group_id => @group.id, target_user_id: users(:f_mentor).id, target_user_type: GroupsController::TargetUserType::INDIVIDUAL, section_type: MentoringModel::Task::Section::UPCOMING.to_s, list_id: "#dummy_link"}
    assert_response :success
    assert_equal [t2], assigns(:section_tasks)
    assert_equal "#dummy_link", assigns(:list_id)
    assert_false assigns(:zero_upcoming_tasks)
    assert_equal users(:f_mentor), assigns(:target_user)
    assert_equal GroupsController::TargetUserType::INDIVIDUAL, assigns(:target_user_type)
    
    t2.destroy
    get :fetch_section_tasks, xhr: true, params: { :group_id => @group.id, target_user_id: users(:f_mentor).id, target_user_type: GroupsController::TargetUserType::INDIVIDUAL, section_type: MentoringModel::Task::Section::UPCOMING.to_s, list_id: "#dummy_link"}
    assert_response :success
    assert_equal [], assigns(:section_tasks)
    assert_equal "#dummy_link", assigns(:list_id)
    assert assigns(:zero_upcoming_tasks)
    assert_equal users(:f_mentor), assigns(:target_user)
    assert_equal GroupsController::TargetUserType::INDIVIDUAL, assigns(:target_user_type)
  end

  def test_should_fetch_tasks_for_other_tasks_section
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    current_user_is :f_mentor
    t1 = create_mentoring_model_task(required: true, due_date: 1.week.ago.utc)
    t2 = create_mentoring_model_task(required: true, due_date: 3.days.from_now.utc)
    t3 = create_mentoring_model_task(required: true, due_date: 16.days.from_now.utc)

    get :fetch_section_tasks, xhr: true, params: { :group_id => @group.id, target_user_id: users(:f_mentor).id, target_user_type: GroupsController::TargetUserType::INDIVIDUAL, section_type: MentoringModel::Task::Section::REMAINING.to_s, list_id: "#dummy_link"}
    assert_response :success
    assert assigns(:section_tasks).include?(t3)
    assert_equal "#dummy_link", assigns(:list_id)
    assert_false assigns(:zero_upcoming_tasks)
    assert_equal users(:f_mentor), assigns(:target_user)
    assert_equal GroupsController::TargetUserType::INDIVIDUAL, assigns(:target_user_type)
  end
   
  def test_update
    put :update, xhr: true, params: { group_id: @group.id, id: @task.id, mentoring_model_task: {
      required: "false", title: "changed title", description: "changed description"
    }}
    @task.reload
    assert_response :success
    assert_equal "changed title", assigns(:task).title
    assert_equal "changed description", assigns(:task).description
    assert_false assigns(:task).required?
    assert_nil assigns(:task).mentoring_model_task_template
    assert_false assigns(:task).unassigned_from_template?
  end

  def test_update_with_vulnerable_content_with_version_v1
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v1")
    assert_no_difference "VulnerableContentLog.count" do
      put :update, xhr: true, params: { group_id: @group.id, id: @task.id, mentoring_model_task: {
        required: "false", title: "changed title", description: "changed description<script>alert(10);</script>"
      }}
    end
  end

  def test_update_with_vulnerable_content_with_version_v2
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v2")
    assert_difference "VulnerableContentLog.count" do
      put :update, xhr: true, params: { group_id: @group.id, id: @task.id, mentoring_model_task: {
        required: "false", title: "changed title", description: "changed description<script>alert(10);</script>"
      }}
    end
    assert_equal @task.reload.description, "changed descriptionalert(10);"
  end

  def test_fetch_associated_goal_and_tasks_with_update
    @group.allow_manage_mm_goals!(@program.roles.for_mentoring_models)
    mmg1 = create_mentoring_model_goal(group_id: @group.id)
    mmt1 = create_mentoring_model_task(group_id: @group.id, goal_id: mmg1.id, required: true)
    mmt2 = create_mentoring_model_task(group_id: @group.id, goal_id: mmg1.id, required: false)
    mmt3 = create_mentoring_model_task(group_id: @group.id, goal_id: mmg1.id, required: true)

    mmg2 = create_mentoring_model_goal(group_id: @group.id)
    mmt4 = create_mentoring_model_task(group_id: @group.id, goal_id: mmg2.id, required: true)

    put :update, xhr: true, params: { group_id: @group.id, id: mmt1.id, mentoring_model_task: {
      required: "true", title: "changed title", description: "changed description", goal_id: mmg2.id, due_date: 4.week.from_now
    }}

    assert_response :success
    assert assigns(:task).required?
    assert assigns(:task).perform_delta
    assert_equal mmg1, assigns(:previous_goal)
    assert_equal [mmt3], assigns(:previous_required_tasks)
    assert_equal mmg2, assigns(:associated_goal)
    assert_equal [mmt4, mmt1.reload], assigns(:required_tasks)
  end

  def test_fetch_associated_goal_and_tasks_with_update_with_target_user
    @group.allow_manage_mm_goals!(@program.roles.for_mentoring_models)
    members = @group.members.to_a
    mmg1 = create_mentoring_model_goal(group_id: @group.id)
    mmt1 = create_mentoring_model_task(group_id: @group.id, goal_id: mmg1.id, required: true, user: @group.members.first)
    mmt2 = create_mentoring_model_task(group_id: @group.id, goal_id: mmg1.id, required: false, user: @group.members.reload.last)
    mmt3 = create_mentoring_model_task(group_id: @group.id, goal_id: mmg1.id, required: true, user: @group.members.reload.last)

    mmg2 = create_mentoring_model_goal(group_id: @group.id)
    mmt4 = create_mentoring_model_task(group_id: @group.id, goal_id: mmg2.id, required: true, user: @group.members.first)

    put :update, xhr: true, params: { group_id: @group.id, id: mmt1.id, mentoring_model_task: {
      required: "true", title: "changed title", description: "changed description", goal_id: mmg2.id, due_date: 4.week.from_now
    }, target_user_id: @group.members.first, target_user_type: GroupsController::TargetUserType::INDIVIDUAL}

    assert_response :success
    assert assigns(:task).required?
    assert assigns(:task).perform_delta
    assert_equal mmg1, assigns(:previous_goal)
    assert_equal [mmt3], assigns(:previous_required_tasks)
    assert_equal mmg2, assigns(:associated_goal)
    assert_equal [mmt4, mmt1.reload], assigns(:required_tasks)
    assert_equal [mmt4, mmt1.reload], assigns(:all_tasks).select{|task| task.class == MentoringModel::Task}
  end

  def test_fetch_associated_goal_and_tasks_with_update_and_no_change_in_previous_goal
    @group.allow_manage_mm_goals!(@program.roles.for_mentoring_models)
    mmg1 = create_mentoring_model_goal(group_id: @group.id)
    mmt1 = create_mentoring_model_task(group_id: @group.id, goal_id: mmg1.id, required: true)
    mmt2 = create_mentoring_model_task(group_id: @group.id, goal_id: mmg1.id, required: false)
    mmt3 = create_mentoring_model_task(group_id: @group.id, goal_id: mmg1.id, required: true)

    put :update, xhr: true, params: { group_id: @group.id, id: mmt3.id, mentoring_model_task: {
      required: "true", title: "changed title", description: "changed description", goal_id: mmg1.id, due_date: 4.week.from_now
    }}

    assert_response :success
    assert assigns(:task).required?
    assert assigns(:task).perform_delta
    assert_nil assigns(:previous_goal)
    assert_equal [], assigns(:previous_required_tasks)
    assert_equal mmg1, assigns(:associated_goal)
    assert_equal [mmt1, mmt3.reload], assigns(:required_tasks)
  end

  def test_update_positions_on_update
    t1 = create_mentoring_model_task(due_date: Time.new(2000), required: true)
    t2 = create_mentoring_model_task(due_date: Time.new(2002), required: true)
    t3 = create_mentoring_model_task(due_date: Time.new(2003), required: true)
    MentoringModel::Task.update_positions(@group.reload.mentoring_model_tasks, t1)
    put :update, xhr: true, params: { group_id: @group.id, id: @task.id, mentoring_model_task: {
      required: true, due_date: DateTime.localize(Time.new(2001), format: :full_display_no_time)
    }}
    assert assigns(:task).perform_delta
    assert_equal [0, 2, 3, 1],  [t1, t2, t3, @task].collect(&:reload).map(&:position)
  end

  def test_destroy
    assert_difference "MentoringModel::Task.count", -1 do
      delete :destroy, xhr: true, params: { group_id: @group.id, id: @task.id}
    end
    assert_response :success
  end

  def test_fetch_associated_goal_and_tasks_with_destroy
    @group.allow_manage_mm_goals!(@program.roles.for_mentoring_models)
    mmg1 = create_mentoring_model_goal(group_id: @group.id)
    mmt1 = create_mentoring_model_task(group_id: @group.id, goal_id: mmg1.id, required: true)
    mmt2 = create_mentoring_model_task(group_id: @group.id, goal_id: mmg1.id, required: true)

    delete :destroy, xhr: true, params: { group_id: @group.id, id: mmt1.id}
    assert_response :success

    assert_equal mmg1, assigns(:associated_goal)
    assert_equal 1, assigns(:required_tasks).count
  end

  def test_fetch_associated_goal_and_tasks_with_destroy_with_target_user
    @group.allow_manage_mm_goals!(@program.roles.for_mentoring_models)
    mmg1 = create_mentoring_model_goal(group_id: @group.id)
    mmt1 = create_mentoring_model_task(group_id: @group.id, goal_id: mmg1.id, required: true, user: @group.members.first)
    mmt2 = create_mentoring_model_task(group_id: @group.id, goal_id: mmg1.id, required: true, user: @group.members.reload.last)
    mmt3 = create_mentoring_model_task(group_id: @group.id, goal_id: mmg1.id, required: true, user: @group.members.first)

    delete :destroy, xhr: true, params: { group_id: @group.id, id: mmt1.id, target_user_id: @group.members.first, target_user_type: GroupsController::TargetUserType::INDIVIDUAL}
    assert_response :success

    assert_equal mmg1, assigns(:associated_goal)
    assert_equal 2, assigns(:required_tasks).count
    assert_equal [mmt3], assigns(:all_tasks).select{|task| task.class == MentoringModel::Task}
  end

  def test_set_status
    @group.allow_manage_mm_goals!(@program.roles.for_mentoring_models)
    assert_equal MentoringModel::Task::Status::TODO, @task.status
    assert_nil @task.completed_date
    assert_nil @task.completed_by
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_TASK).once
    post :set_status, xhr: true, params: { group_id: @group.id, id: @task.id, completed: 'true'}
    assert assigns(:task).perform_delta
    assert_equal MentoringModel::Task::Status::DONE, @task.reload.status
    assert_equal Date.today, @task.completed_date
    assert_equal @user.id, @task.completed_by
    assert_nil assigns(:associated_goal)
  end

  def test_set_status_for_associated_goal
    @group.allow_manage_mm_goals!(@program.roles.for_mentoring_models)
    assert_equal MentoringModel::Task::Status::TODO, @task.status
    mmg1 = create_mentoring_model_goal
    @task.update_attribute(:goal_id, mmg1.id)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_TASK).once
    post :set_status, xhr: true, params: { group_id: @group.id, id: @task.id, completed: 'true'}
    @task.reload
    assert assigns(:task).perform_delta
    assert_equal Date.today, @task.completed_date
    assert_equal mmg1, assigns(:associated_goal)
  end

  def test_set_status_for_completed_date
    assert_nil @task.completed_date
    assert_equal MentoringModel::Task::Status::TODO, @task.status
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_TASK).never
    post :set_status, xhr: true, params: { group_id: @group.id, id: @task.id}
    assert assigns(:task).perform_delta
    assert_nil @task.completed_date
    assert_equal MentoringModel::Task::Status::TODO, @task.status
  end

  def test_setup_meeting
    @group.allow_manage_mm_meetings!(@program.get_role(RoleConstants::MENTOR_NAME))

    get :setup_meeting, xhr: true, params: { group_id: @group.id, id: @task.id}
    assert_response :success

    assert_not_nil assigns(:new_meeting)
    assert_template :setup_meeting
  end

  def test_check_access
    @group.deny_manage_mm_tasks!(@program.get_role(RoleConstants::MENTOR_NAME))
    assert_permission_denied do
      get :new, xhr: true, params: { group_id: @group.id}
    end
  end

  def test_check_task_owner_for_set_status
    task = create_mentoring_model_task(user: users(:mkr_student))
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_TASK).never
    assert_permission_denied do
      post :set_status, xhr: true, params: { group_id: @group.id, id: task.id, completed: 'true'}
    end
  end

  def test_check_mentoring_connection_meeting_enabled
    task = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::MEETING)
    @group.deny_manage_mm_meetings!(@program.get_role(RoleConstants::MENTOR_NAME))
    assert_permission_denied do
      get :setup_meeting, xhr: true, params: { id: task.id, group_id: @group.id }
    end
  end

  def test_restrict_altering_of_tasks_from_template_for_update
    @task.update_attribute(:from_template, true)
    assert_permission_denied do
      put :update, xhr: true, params: { group_id: @group.id, id: @task.id, mentoring_model_task: {
        required: "false", title: "changed title", description: "changed description"
      }}
    end
  end

  def test_restrict_altering_of_tasks_from_template_for_destroy
    @task.update_attribute(:from_template, true)
    assert_permission_denied do
      delete :destroy, xhr: true, params: { group_id: @group.id, id: @task.id}
    end
  end

  def test_assert_permission_denied_on_update_position_of_required_task
    @task.update_attributes({required: true, due_date: Time.new(2000)})
    t1 = create_mentoring_model_task(due_date: Time.new(2000), required: true)
    assert_permission_denied do
      post :update_positions, xhr: true, params: { group_id: @group.id, id: @task.id, mentoring_model_task: [t1, @task].map(&:id)}
    end
  end

  def test_update_positions_between_required
    t1 = create_mentoring_model_task(due_date: Time.new(2000), required: true)
    t2 = create_mentoring_model_task(due_date: Time.new(2002), required: true)
    t3 = create_mentoring_model_task
    t4 = create_mentoring_model_task
    post :update_positions, xhr: true, params: { group_id: @group.id, id: @task.id, mentoring_model_task: [t1, @task, t2, t3, t4].map(&:id)}
    assert_equal [t1, @task, t2, t3, t4].map(&:id), @group.mentoring_model_tasks.collect(&:id)
    assert_equal [0, 1, 2, 3, 4], @group.mentoring_model_tasks.collect(&:position)
    assert_nil @task.perform_delta
  end

  def test_update_positions_between_required_and_optional
    t1 = create_mentoring_model_task(due_date: Time.new(2000), required: true)
    t2 = create_mentoring_model_task(due_date: Time.new(2002), required: true)
    t3 = create_mentoring_model_task
    t4 = create_mentoring_model_task
    post :update_positions, xhr: true, params: { group_id: @group.id, id: @task.id, mentoring_model_task: [t1, t2, @task, t3, t4].map(&:id)}
    assert_equal [t1, t2, @task, t3, t4].map(&:id), @group.mentoring_model_tasks.collect(&:id)
    assert_equal [0, 1, 2, 3, 4], @group.mentoring_model_tasks.collect(&:position)
    assert_nil @task.perform_delta
  end

  def test_update_positions_between_otpional
    t1 = create_mentoring_model_task(due_date: Time.new(2000), required: true)
    t2 = create_mentoring_model_task(due_date: Time.new(2002), required: true)
    t3 = create_mentoring_model_task
    t4 = create_mentoring_model_task
    post :update_positions, xhr: true, params: { group_id: @group.id, id: @task.id, mentoring_model_task: [t1, t2, t3, @task, t4].map(&:id)}
    assert_equal [t1, t2, t3, @task, t4].map(&:id), @group.mentoring_model_tasks.collect(&:id)
    assert_equal [0, 1, 2, 3, 4], @group.mentoring_model_tasks.collect(&:position)
    assert_nil @task.perform_delta
  end

  def test_in_current_view_properly_set
    # default @task in this place # false
    t01 = create_mentoring_model_task(required: false) # false
    t02 = create_mentoring_model_task(required: true, due_date: 1.week.ago, status: MentoringModel::Task::Status::DONE) # false
    t03 = create_mentoring_model_task(required: false) # false
    ta4 = create_mentoring_model_task(required: true, due_date: 3.days.ago) # true
    ta5 = create_mentoring_model_task(required: false) # false
    t04 = create_mentoring_model_task(required: true, due_date: 2.days.ago, status: MentoringModel::Task::Status::DONE) # false
    t05 = create_mentoring_model_task(required: false) # true
    t06 = create_mentoring_model_task(required: true, due_date: 2.days.from_now, user: users(:mkr_student)) # true
    t07 = create_mentoring_model_task(required: false) # true
    t08 = create_mentoring_model_task(required: false, status: MentoringModel::Task::Status::DONE) # true
    t09 = create_mentoring_model_task(required: true, due_date: 4.days.from_now, status: MentoringModel::Task::Status::DONE) # true
    t10 = create_mentoring_model_task(required: true, due_date: 5.days.from_now) # true
    t11 = create_mentoring_model_task(required: false) # true
    t12 = create_mentoring_model_task(required: false, status: MentoringModel::Task::Status::DONE) # true
    t13 = create_mentoring_model_task(required: true, due_date: 9.days.from_now) # false
    t14 = create_mentoring_model_task(required: true, due_date: 12.days.from_now, status: MentoringModel::Task::Status::DONE) # false
    t15 = create_mentoring_model_task(required: false, due_date: 13.days.from_now) # false
    put :update, xhr: true, params: { group_id: @group.id, id: @task.id, mentoring_model_task: {
      required: "false", title: "changed title", description: "changed description"
    }}
  end

  def test_new_for_milestone_permission_denied
    current_user_is :f_mentor

    assert_permission_denied do
      get :new, xhr: true, params: { milestone_id: 1, group_id: @group.id}
    end
  end

  def test_new_for_milestone_success
    @group.allow_manage_mm_milestones!(@program.roles.for_mentoring_models)
    milestone = create_mentoring_model_milestone
    current_user_is :f_mentor

    get :new, xhr: true, params: { milestone_id: milestone.id, group_id: @group.id}
    assert_response :success

    assert_equal milestone, assigns(:milestone)
    assert_equal milestone.id, assigns(:task).milestone_id
  end

  def test_create_with_milestone
    MentoringModel::Task.destroy_all
    @group.allow_manage_mm_milestones!(@program.roles.for_mentoring_models)
    milestone = create_mentoring_model_milestone
    current_user_is :f_mentor

    post :create, xhr: true, params: { group_id: @group.id, mentoring_model_task: {
      connection_membership_id: Connection::Membership.where(group_id: @group.id, user_id: @user.id)[0].id,
      required: false,
      title: "Carrie Mathison",
      description: "Claire Danes",
      status: MentoringModel::Task::Status::TODO,
      milestone_id: milestone.id
    }}
    assert_response :success

    assert assigns(:from_milestone)
    assert assigns(:all_tasks).is_a?(Hash)
    assert_equal [milestone.id], assigns(:all_tasks).keys
    assert assigns(:all_tasks).values.flatten.include?(MentoringModel::Task.last)
  end

  def test_unassigned_tasks_can_be_edited
    current_user_is :f_mentor
    task = create_mentoring_model_task(connection_membership_id: nil)

    get :edit, xhr: true, params: { :id => task.id, :group_id => @group.id}
    assert_response :success
  end

  def test_unassigned_tasks_status_can_be_changed
    current_user_is :f_mentor
    task = create_mentoring_model_task(connection_membership_id: nil)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_TASK).once
    get :set_status, xhr: true, params: { :id => task.id, :group_id => @group.id, completed: "true"}
    assert_response :success

    assert_equal MentoringModel::Task::Status::DONE, assigns(:task).status
  end

  def test_update_for_unassigned_tasks
    cm = Connection::Membership.where(group_id: @group.id, user_id: users(:f_mentor).id)[0]
    @task = create_mentoring_model_task(required: true, title: "Carrie Mathison", description: "Robin Wright", from_template: true, connection_membership_id: nil)

    put :update, xhr: true, params: { group_id: @group.id, id: @task.id, mentoring_model_task: {
      required: "false", title: "Claire Underwood", description: "Claire Danes", connection_membership_id: cm.id
    }}
    assert_response :success

    @task.reload
    assert_equal "Carrie Mathison", assigns(:task).title
    assert_equal "Robin Wright", assigns(:task).description
    assert assigns(:task).required?
    assert_equal users(:f_mentor), assigns(:task).user
    assert_false @group.mentoring_model.allow_due_date_edit
  end

  def test_edit_assignee_or_due_date
    @task = create_mentoring_model_task(required: true, title: "Carrie Mathison", description: "Robin Wright", from_template: true, connection_membership_id: nil, unassigned_from_template: true)

    get :edit_assignee_or_due_date, xhr: true, params: { group_id: @group.id, id: @task.id}
    assert_response :success
  end

  def test_edit_due_date_for_template_task_without_permission
    @task = create_mentoring_model_task(required: true, title: "Carrie Mathison", description: "Robin Wright", from_template: true, connection_membership_id: nil, unassigned_from_template: false)

    assert_permission_denied do
      get :edit_assignee_or_due_date, xhr: true, params: { group_id: @group.id, id: @task.id}
    end
  end

  def test_edit_due_date_for_template_task_with_permission
    @task = create_mentoring_model_task(required: true, title: "Carrie Mathison", description: "Robin Wright", from_template: true, connection_membership_id: nil, unassigned_from_template: false)

    @group.mentoring_model.allow_due_date_edit = true
    @group.mentoring_model.save!
    get :edit_assignee_or_due_date, xhr: true, params: { group_id: @group.id, id: @task.id}
    assert_response :success
  end

  def test_edit_due_date_for_template_task_with_both_permissions
    @task = create_mentoring_model_task(required: true, title: "Carrie Mathison", description: "Robin Wright", from_template: true, connection_membership_id: nil, unassigned_from_template: true)

    @group.mentoring_model.allow_due_date_edit = true
    @group.mentoring_model.save!
    get :edit_assignee_or_due_date, xhr: true, params: { group_id: @group.id, id: @task.id}
    assert_response :success
  end


  def test_edit_assignee_or_due_date_permission_denied
    @task = create_mentoring_model_task(required: true, title: "Carrie Mathison", description: "Robin Wright", unassigned_from_template: false)

    assert_permission_denied do
      get :edit_assignee_or_due_date, xhr: true, params: { group_id: @group.id, id: @task.id}
    end
  end

  def test_update_assignee_permission_denied
    @task = create_mentoring_model_task(required: true, title: "Carrie Mathison", description: "Robin Wright", from_template: true, unassigned_from_template: false)

    assert_permission_denied do
      put :update_assignee_or_due_date, xhr: true, params: { group_id: @group.id, id: @task.id}
    end
  end

  def test_due_date_permission_denied
    @task = create_mentoring_model_task(required: true, title: "Carrie Mathison", description: "Robin Wright", from_template: true)

    @group.mentoring_model.allow_due_date_edit = false
    @group.mentoring_model.save!

    assert_permission_denied do
      put :update_assignee_or_due_date, xhr: true, params: { group_id: @group.id, id: @task.id}
    end
  end

  def test_update_assignee_or_due_date_permission_denied
    @task = create_mentoring_model_task(required: true, title: "Carrie Mathison", description: "Robin Wright", from_template: true, unassigned_from_template: false)

    @group.mentoring_model.allow_due_date_edit = false
    @group.mentoring_model.save!

    assert_permission_denied do
      put :update_assignee_or_due_date, xhr: true, params: { group_id: @group.id, id: @task.id}
    end
  end

  def test_update_assignee_success
    task_template = create_mentoring_model_task_template(role_id: nil)
    @task = create_mentoring_model_task(required: true, title: "Carrie Mathison", description: "Robin Wright", from_template: true, connection_membership_id: nil, mentoring_model_task_template_id: task_template.id, unassigned_from_template: true)
    connection_membership = Connection::Membership.where(group_id: @group.id, user_id: users(:f_mentor).id)[0]

    put :update_assignee_or_due_date, xhr: true, params: { group_id: @group.id, id: @task.id, mentoring_model_task: {connection_membership_id: connection_membership.id}}
    assert_response :success

    assert_equal connection_membership, assigns(:task).connection_membership
    assert_equal users(:f_mentor), assigns(:task).user
    assert assigns(:task).unassigned_from_template?
  end

  def test_update_due_date_from_template_success
    milestone_template = create_mentoring_model_milestone_template({mentoring_model_id: @group.mentoring_model.id, title: "one"})
    @group.mentoring_model.allow_due_date_edit = true
    @group.allow_manage_mm_milestones!(programs(:albers).roles.for_mentoring_models)
    @group.mentoring_model.save!
    milestone_id = @group.mentoring_model_milestones.first.id

    task_template = create_mentoring_model_task_template()
    @mentor_task = create_mentoring_model_task(required: true, title: "Mentor task", from_template: true, mentoring_model_task_template_id: task_template.id)
    @mentee_task = create_mentoring_model_task(user: @group.members.last, required: true, title: "Mentee task", from_template: true, mentoring_model_task_template_id: task_template.id)
    @mentor_task.update_attributes!(milestone_id: milestone_id)
    @mentee_task.update_attributes!(milestone_id: milestone_id)

    put :update_assignee_or_due_date, xhr: true, params: { group_id: @group.id, target_user_type: GroupsController::TargetUserType::INDIVIDUAL, target_user_id: @user.id, view_mode: MentoringModelUtils::ViewMode::SORT_BY_MILESTONES, id: @mentor_task.id, mentoring_model_task: {due_date: Date.today, required: "true", milestone_id: milestone_id}}
    assert_response :success

    assert_equal @user, assigns(:target_user)
    all_tasks_connection_membership_ids = assigns(:all_tasks).values.first.collect(&:connection_membership_id)
    user_connection_membership_ids = @user.connection_memberships.collect(&:id)
    assert_equal_unordered user_connection_membership_ids, all_tasks_connection_membership_ids
    assert_false assigns(:task).unassigned_from_template?
    assert_equal assigns(:task).due_date, Date.today
  end

  def test_update_assignee_or_due_date_success
    task_template = create_mentoring_model_task_template(role_id: nil)
    @task = create_mentoring_model_task(required: true, title: "Carrie Mathison", description: "Robin Wright", from_template: true, connection_membership_id: nil, mentoring_model_task_template_id: task_template.id, unassigned_from_template: true)
    connection_membership = Connection::Membership.where(group_id: @group.id, user_id: users(:f_mentor).id)[0]

    @group.mentoring_model.allow_due_date_edit = false
    @group.mentoring_model.save!
    put :update_assignee_or_due_date, xhr: true, params: { group_id: @group.id, id: @task.id, mentoring_model_task: {connection_membership_id: connection_membership.id, due_date: Date.today}}
    assert_response :success

    assert_equal connection_membership, assigns(:task).connection_membership
    assert_equal users(:f_mentor), assigns(:task).user
    assert assigns(:task).unassigned_from_template?
  end

  def test_update_assignee_success_with_unassigned_from_template
    task_template = create_mentoring_model_task_template(role_id: nil)
    @task = create_mentoring_model_task(required: true, title: "Carrie Mathison", description: "Robin Wright", from_template: true, mentoring_model_task_template_id: task_template.id, unassigned_from_template: true)
    assert_equal users(:f_mentor), @task.user
    connection_membership = Connection::Membership.where(group_id: @group.id, user_id: users(:mkr_student).id)[0]

    @group.mentoring_model.allow_due_date_edit = false
    @group.mentoring_model.save!
    put :update_assignee_or_due_date, xhr: true, params: { group_id: @group.id, id: @task.id, mentoring_model_task: {connection_membership_id: connection_membership.id}, due_date: Date.today}
    assert_response :success

    assert_equal connection_membership, assigns(:task).connection_membership
    assert_equal users(:mkr_student), assigns(:task).user
    assert assigns(:task).unassigned_from_template?
  end

  def test_edit_assignee_success_with_unassigned_from_template
    @task = create_mentoring_model_task(required: true, title: "Carrie Mathison", description: "Robin Wright", from_template: true, unassigned_from_template: true)

    get :edit_assignee_or_due_date, xhr: true, params: { group_id: @group.id, id: @task.id}
    assert_response :success
  end

  def test_show
    group = groups(:mygroup)
    task_1 = create_mentoring_model_task()
    comment1 = create_task_comment(task_1, {notify: 1})
    get :show, xhr: true, params: { id: task_1.id, group_id: group.id, format: :js, home_page_view: true}
    assert_equal [comment1], assigns(:comments_and_checkins)
    assert assigns(:notify_checked)
    assert assigns(:home_page_view)
  end

  def test_show_in_closed_group
    group = groups(:mygroup)
    task_1 = create_mentoring_model_task()
    comment1 = create_task_comment(task_1, {notify: 1})
    user = users(:mkr_student)
    group.terminate!(users(:f_admin), "sample termination reason", group.get_auto_terminate_reason_id, Group::TerminationMode::INACTIVITY)
    current_user_is user

    assert group.has_member?(user)
    assert group.closed?

    get :show, xhr: true, params: { id: task_1.id, group_id: group.id, format: :js}
    assert_response :success
    assert_equal [comment1], assigns(:comments_and_checkins)
    assert_nil assigns(:notify_checked)
  end

  def test_new_for_program_with_disabled_ongoing_mentoring
    #disabling ongoing mentoring
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)

    assert_permission_denied do
      get :new, xhr: true, params: { group_id: @group.id}
    end
  end

  def test_notify_checked_for_multi_group
    group = groups(:mygroup)
    group.update_members(group.mentors, group.students + [users(:f_student)])
    group.reload
    task_1 = create_mentoring_model_task()
    comment1 = create_task_comment(task_1)
    get :show, xhr: true, params: { id: task_1.id, group_id: group.id, format: :js}
    assert_response :success
    assert_equal [comment1], assigns(:comments_and_checkins)
    assert_false assigns(:notify_checked)
  end
end
