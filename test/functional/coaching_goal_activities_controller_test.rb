require_relative './../test_helper.rb'

class CoachingGoalActivitiesControllerTest < ActionController::TestCase
  def setup
    super
    programs(:albers).enable_feature(FeatureName::COACHING_GOALS)
    @group = groups(:mygroup)
    @student = @group.students.first
    @mentor = @group.mentors.first
    @coaching_goal = create_coaching_goal(:group_id => @group.id)
  end

  def test_permission_denied_when_feature_disabled
    programs(:albers).enable_feature(FeatureName::COACHING_GOALS, false)
    current_user_is @mentor
    assert_permission_denied { get :new, xhr: true, params: { :group_id => @group.id, :coaching_goal_id => @coaching_goal.id}}
  end

  def test_permission_denied_for_closed_connection
    groups(:mygroup).terminate!(users(:f_admin),"Test reason", groups(:mygroup).program.permitted_closure_reasons.first.id)
    current_user_is @mentor

    assert_permission_denied do
      get :new, xhr: true, params: { :group_id => @group.id, :coaching_goal_id => @coaching_goal.id}
    end
  end

  def test_new
    current_user_is @mentor

    get :new, xhr: true, params: { :group_id => @group.id, :coaching_goal_id => @coaching_goal.id}
    assert_response :success

    assert assigns(:coaching_goal_activity).new_record?
    assert_equal @coaching_goal, assigns(:coaching_goal)
    assert_equal @group, assigns(:group)
    assert_equal @group.membership_of(@mentor), assigns(:current_connection_membership)

    assert_select ".modal-header" do
      assert_select "h4", :text => "Update Goal Progress"
    end
    assert_select ".modal-body" do
      assert_select "form" do
        assert_select "div#cjs_slider_enclosure" do
          assert_select "label.control-label", :text => "Current Progress: 0%"
        end
      end
    end
  end

  def test_create
    current_user_is @mentor

    assert_equal 0, @coaching_goal.completed_percentage

    assert_difference "Connection::Activity.count" do
      assert_difference "RecentActivity.count" do
        assert_difference "CoachingGoalActivity.count" do
          post :create, xhr: true, params: { :group_id => @group.id, :coaching_goal_id => @coaching_goal.id, :progress_slider => "36",
            :coaching_goal_activity => {:message => "Sample"}, :is_show_page => "true"
          }
          assert_response :success
        end
      end
    end

    assert_equal @coaching_goal, assigns(:coaching_goal)
    assert_equal @group, assigns(:group)
    assert_equal @group.membership_of(@mentor), assigns(:current_connection_membership)
    assert_equal 36, @coaching_goal.reload.completed_percentage
    assert_equal "Sample", assigns(:coaching_goal_activity).message
    assert_equal 36.0, assigns(:coaching_goal_activity).progress_value
    assert_equal @mentor, assigns(:coaching_goal_activity).initiator
    assert_equal @coaching_goal, assigns(:coaching_goal_activity).coaching_goal
    assert assigns(:side_pane_coaching_goals).present?
    assert_equal assigns(:coaching_goal_activity).recent_activities.last, RecentActivity.last
    assert_false assigns(:is_message_post)
    assert assigns(:from_coaching_goals_show)
  end

  def test_comment_create_in_show_message_box
    current_user_is @mentor

    assert_equal 0, @coaching_goal.completed_percentage

    assert_difference "Connection::Activity.count" do
      assert_difference "RecentActivity.count" do
        assert_difference "CoachingGoalActivity.count" do
          post :create, xhr: true, params: { :group_id => @group.id, :coaching_goal_id => @coaching_goal.id, :progress_slider => "36",
            :coaching_goal_activity => {:message => "Sample"}, :is_show_page => "true", :refresh_ra => true
          }
          assert_response :success
        end
      end
    end

    assert_equal @coaching_goal, assigns(:coaching_goal)
    assert_equal @group, assigns(:group)
    assert_equal @group.membership_of(@mentor), assigns(:current_connection_membership)

    assert_equal 0, @coaching_goal.reload.completed_percentage
    assert_equal "Sample", assigns(:coaching_goal_activity).message
    assert_nil assigns(:coaching_goal_activity).progress_value
    assert_equal @mentor, assigns(:coaching_goal_activity).initiator
    assert_equal @coaching_goal, assigns(:coaching_goal_activity).coaching_goal
    assert assigns(:side_pane_coaching_goals).present?
    assert assigns(:is_message_post)
    assert assigns(:from_coaching_goals_show)
    assert_equal assigns(:coaching_goal_activity).recent_activities.last, RecentActivity.last
  end

  def test_create_when_message_is_blank
    current_user_is @mentor

    assert_equal 0, @coaching_goal.completed_percentage

    assert_difference "Connection::Activity.count" do
      assert_difference "RecentActivity.count" do
        assert_difference "CoachingGoalActivity.count" do
          post :create, xhr: true, params: { :group_id => @group.id, :coaching_goal_id => @coaching_goal.id, :progress_slider => "36",
            :coaching_goal_activity => {:message => ""}
          }
          assert_response :success
        end
      end
    end

    assert_equal 36, @coaching_goal.reload.completed_percentage
    assert_nil assigns(:coaching_goal_activity).message
    assert_equal 36.0, assigns(:coaching_goal_activity).progress_value
    assert_equal @mentor, assigns(:coaching_goal_activity).initiator
    assert_equal @coaching_goal, assigns(:coaching_goal_activity).coaching_goal
    assert assigns(:side_pane_coaching_goals).present?
  end

  def test_create_when_progress_is_unchanged
    current_user_is @mentor
    create_coaching_goal_activity(@coaching_goal, :progress_value => 72, :initiator => @mentor)
    assert_equal 72, @coaching_goal.reload.completed_percentage

    assert_difference "Connection::Activity.count" do
      assert_difference "RecentActivity.count" do
        assert_difference "CoachingGoalActivity.count" do
          post :create, xhr: true, params: { :group_id => @group.id, :coaching_goal_id => @coaching_goal.id, :progress_slider => "72",
            :coaching_goal_activity => {:message => "Sample"}
          }
          assert_response :success
        end
      end
    end

    assert_equal 72, @coaching_goal.reload.completed_percentage
    assert_equal "Sample", assigns(:coaching_goal_activity).message
    assert_nil assigns(:coaching_goal_activity).progress_value
    assert_equal @mentor, assigns(:coaching_goal_activity).initiator
    assert_equal @coaching_goal, assigns(:coaching_goal_activity).coaching_goal
    assert assigns(:side_pane_coaching_goals).present?
  end

  def test_raise_exception_when_message_and_slider_absent
    current_user_is @mentor
    connection_membership = @group.membership_of(@mentor)

    assert_multiple_errors([{:field => :message, :message => "can't be blank"}, {:field => :progress_value, :message => "can't be blank"}]) do
      post :create, xhr: true, params: { :group_id => @group.id, :coaching_goal_id => @coaching_goal.id, :progress_slider => "",
        :coaching_goal_activity => {:message => ""}
      }
    end
  end

end
