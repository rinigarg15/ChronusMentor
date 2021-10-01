require_relative './../../test_helper.rb'

class CoachingGoalActivityObserverTest < ActiveSupport::TestCase
  def test_after_create
    coaching_goal = create_coaching_goal
    coaching_goal_activity = nil
    assert_difference "PendingNotification.count" do
      assert_difference "RecentActivity.count" do
        assert_difference "Connection::Activity.count" do
          coaching_goal_activity = create_coaching_goal_activity(coaching_goal, :progress_value => 72, :initiator => users(:f_mentor))
        end
      end
    end
    recent_activity = RecentActivity.last
    assert_equal coaching_goal, recent_activity.ref_obj.coaching_goal
    assert_equal coaching_goal_activity, recent_activity.ref_obj
    assert_equal RecentActivityConstants::Type::COACHING_GOAL_ACTIVITY_CREATION, recent_activity.action_type
  end
end