require_relative './../test_helper.rb'

class CoachingGoalsControllerTest < ActionController::TestCase
  def setup
    super
    @group = groups(:mygroup)
    @student = @group.students.first
    @mentor = @group.mentors.first
    programs(:albers).enable_feature(FeatureName::COACHING_GOALS)
  end

  def test_permission_denied_when_feature_disabled
    programs(:albers).enable_feature(FeatureName::COACHING_GOALS, false)
    coaching_goal = create_coaching_goal
    current_user_is @mentor
    assert_permission_denied { get :show, params: { :group_id => @group.id, :id => coaching_goal.id}}
  end

  def test_disallow_page_controls_when_confidential_access_for_index
    current_user_is :f_admin
    programs(:albers).confidentiality_audit_logs.create!(:user_id => users(:f_admin).id, :reason =>"This is another reason", :group_id => @group.id)

    get :index, params: { :group_id => @group.id}
    assert_response :success

    assert_false assigns(:page_controls_allowed)    
  end

  def test_disallow_page_controls_when_confidential_access_for_show
    current_user_is :f_admin
    coaching_goal = create_coaching_goal
    programs(:albers).confidentiality_audit_logs.create!(:user_id => users(:f_admin).id, :reason =>"This is another reason", :group_id => @group.id)

    get :show, params: { :group_id => @group.id, :id => coaching_goal.id}
    assert_response :success

    assert_false assigns(:page_controls_allowed)    
  end

  def test_should_not_raise_permission_denied_for_closed_connection
    groups(:mygroup).terminate!(users(:f_admin),"Test reason", groups(:mygroup).program.permitted_closure_reasons.first.id)
    current_user_is @mentor

    get :index, params: { :group_id => @group.id}
    assert_response :success

    assert_false assigns(:page_controls_allowed)    
  end

  def test_should_no_raise_permission_denied_for_closed_connection_more_activities
    groups(:mygroup).terminate!(users(:f_admin),"Test reason", groups(:mygroup).program.permitted_closure_reasons.first.id)
    coaching_goal = create_coaching_goal

    current_user_is @mentor

    get :more_activities, xhr: true, params: { :group_id => @group.id, :id => coaching_goal.id}
    assert_response :success

    assert_false assigns(:page_controls_allowed)    
  end

  def test_should_raise_permission_denied_creating_a_goal_for_closed_connection
    groups(:mygroup).terminate!(users(:f_admin),"Test reason", groups(:mygroup).program.permitted_closure_reasons.first.id)
    current_user_is :f_mentor
    
    assert_permission_denied do
      post :create, params: { :coaching_goal => {:title => "New Goal", :due_date => 7.days.from_now}, :group_id => @group.id}
    end  
  end

  def test_create_new_goal
    current_user_is @mentor

    assert_difference('@group.coaching_goals.count') do
      post :create, params: { :coaching_goal => {:title => "New Goal", :due_date => 7.days.from_now}, :group_id => @group.id}
    end

    goal = @group.coaching_goals.first
    assert_nil goal.student_membership
    assert_equal goal.title, "New Goal"
  end

  def test_index_goal
    current_user_is @mentor
    coaching_goal = create_coaching_goal

    get :index, params: { :group_id => @group.id}
    assert_response :success

    assert assigns(:coaching_goal).new_record?
    assert_equal [coaching_goal], assigns(:group_coaching_goals)
  end

  def test_update_goal
    current_user_is @mentor
    coaching_goal = create_coaching_goal
    new_title = "My goal"
    new_desc = "Goes around, comes around"

    assert_no_difference('RecentActivity.count') do
      post :update, xhr: true, params: { :coaching_goal => {:title => new_title, :description => new_desc}, :id => coaching_goal.id, :group_id => @group.id}
    end
    assert_response :success
    
    assert_equal coaching_goal.reload.title, new_title
    assert_equal coaching_goal.description, new_desc

    assert_difference('RecentActivity.count') do
      post :update, xhr: true, params: { :coaching_goal => {:due_date => 7.days.from_now}, :id => coaching_goal.id, :group_id => @group.id}
    end
    assert_response :success
    assert_equal coaching_goal.reload.due_date, 7.days.from_now.to_date
    assert_equal assigns(:coaching_goal).recent_activities.last, assigns(:recent_activity)
  end

  def test_show_goal
    current_user_is @mentor
    coaching_goal = create_coaching_goal
    get :show, params: { :id => coaching_goal.id, :group_id => @group.id}
    assert_response :success

    assert_equal coaching_goal, assigns(:coaching_goal)
  end

  def test_edit_goal
    current_user_is @mentor
    coaching_goal = create_coaching_goal
    get :edit, xhr: true, params: { :id => coaching_goal.id, :group_id => @group.id}
    assert_response :success

    assert_equal coaching_goal, assigns(:coaching_goal)
  end

  def test_destroy_goal
    current_user_is @mentor
    coaching_goal = create_coaching_goal
    assert_difference('@group.coaching_goals.count', -1) do
      post :destroy, params: { :id => coaching_goal.id, :group_id => @group.id}
    end

    assert_redirected_to group_coaching_goals_path
    assert_equal "The goal has been successfully deleted", flash[:notice]
  end

  def test_side_pane_content
    # Timecop is used here to set the created_at
    current_user_is @mentor
    coaching_goal1 = nil
    time_traveller(4.days.ago) do
      coaching_goal1 = create_coaching_goal
    end
    coaching_goal2 = nil
    time_traveller(3.days.ago) do
      coaching_goal2 = create_coaching_goal(:due_date => (Time.now - 10.days).to_date)
    end
    coaching_goal3 = nil
    time_traveller(2.days.ago) do
      coaching_goal3 = create_coaching_goal(:due_date => (Time.now + 10.days).to_date)
    end
    coaching_goal4 = nil
    time_traveller(1.days.ago) do
      coaching_goal4 = create_coaching_goal(:due_date => (Time.now - 11.days).to_date)
    end

    create_coaching_goal_activity(coaching_goal4, :progress_value => "100", :initiator => @mentor)

    get :show, params: { :id => coaching_goal1.id, :group_id => @group.id}
    assert_response :success

    assert_equal coaching_goal1.id, assigns(:coaching_goal).id
    assert_equal [coaching_goal2, coaching_goal3, coaching_goal1, coaching_goal4], assigns(:side_pane_coaching_goals)
    assert_nil assigns(:skip_coaching_goals_side_pane)
  end

  def test_side_pane_content_with_completed
    # Timecop is used here to set the created_at
    current_user_is @mentor
    coaching_goal1 = nil
    time_traveller(4.days.ago) do
      coaching_goal1 = create_coaching_goal
    end
    coaching_goal2 = nil
    time_traveller(3.days.ago) do
      coaching_goal2 = create_coaching_goal(:due_date => (Time.now - 10.days).to_date)
    end
    coaching_goal3 = nil
    time_traveller(2.days.ago) do
      coaching_goal3 = create_coaching_goal(:due_date => (Time.now + 10.days).to_date)
    end
    coaching_goal4 = nil
    time_traveller(1.days.ago) do
      coaching_goal4 = create_coaching_goal(:due_date => (Time.now - 11.days).to_date)
    end

    get :index, params: { :group_id => @group.id}
    assert_response :success

    assert assigns(:coaching_goal).new_record?
    assert assigns(:skip_coaching_goals_side_pane)
    assert_nil assigns(:side_pane_coaching_goals)
    assert_equal [coaching_goal4, coaching_goal3, coaching_goal2, coaching_goal1], assigns(:group_coaching_goals)
  end

  def test_more_activities
    current_user_is @mentor
    coaching_goal1 = create_coaching_goal
    activity = create_coaching_goal_activity(coaching_goal1, :progress_value => "100", :initiator => @mentor)

    get :more_activities, xhr: true, params: { :id => coaching_goal1.id, :group_id => @group.id}
    assert_response :success

    assert assigns(:coaching_goal_activities).present?
    assert_equal [activity.recent_activities.last, coaching_goal1.recent_activities.last], assigns(:coaching_goal_activities)
    assert_equal CoachingGoalsController::ACTIVITIES_PER_PAGE, assigns(:new_offset_id)
  end

  def test_more_activities_with_offset
    current_user_is @mentor
    coaching_goal1 = create_coaching_goal
    activity = create_coaching_goal_activity(coaching_goal1, :progress_value => "100", :initiator => @mentor)

    get :more_activities, xhr: true, params: { :id => coaching_goal1.id, :group_id => @group.id, :offset_id => 1}
    assert_response :success

    assert assigns(:coaching_goal_activities).present?
    assert_equal [coaching_goal1.recent_activities.last], assigns(:coaching_goal_activities)
    assert_equal CoachingGoalsController::ACTIVITIES_PER_PAGE + 1, assigns(:new_offset_id)
  end
end
