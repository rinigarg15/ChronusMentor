require_relative './../test_helper.rb'

class CoachingGoalActivityTest < ActiveSupport::TestCase
  def test_validations
    coaching_goal_activity = CoachingGoalActivity.new
    assert_false coaching_goal_activity.valid?
    assert_equal(["can't be blank"], coaching_goal_activity.errors[:coaching_goal])
    assert_equal(["can't be blank"], coaching_goal_activity.errors[:message])
    assert_equal(["can't be blank"], coaching_goal_activity.errors[:progress_value])

    coaching_goal_activity = CoachingGoalActivity.new(:message => "Sample")
    assert_false coaching_goal_activity.valid?
    assert coaching_goal_activity.errors[:message].blank?
    assert coaching_goal_activity.errors[:progress_value].blank?

    coaching_goal_activity = CoachingGoalActivity.new(:progress_value => 20)
    assert_false coaching_goal_activity.valid?
    assert coaching_goal_activity.errors[:message].blank?
    assert coaching_goal_activity.errors[:progress_value].blank?
  end

  def test_recent
    initiator = users(:f_mentor)
    coaching_goal = create_coaching_goal
    coaching_goal_activity = create_coaching_goal_activity(coaching_goal, :progress_value => 72, :initiator => initiator)

    assert_equal 1, coaching_goal.reload.coaching_goal_activities.recent.size
    assert_equal coaching_goal_activity, coaching_goal.coaching_goal_activities.recent.first

    coaching_goal_activity2 = nil
    time_traveller(2.days.from_now) do
      coaching_goal_activity2 = create_coaching_goal_activity(coaching_goal, :progress_value => 84, :initiator => initiator)    
    end    
    assert_equal 2, coaching_goal.reload.coaching_goal_activities.recent.size
    assert_equal coaching_goal_activity2, coaching_goal.coaching_goal_activities.recent.first
  end
end
