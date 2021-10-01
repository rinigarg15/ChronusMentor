require_relative './../../test_helper.rb'

class CoachingGoalObserverTest < ActiveSupport::TestCase

  def setup
    super
    programs(:albers).enable_feature(FeatureName::COACHING_GOALS)
    @group = groups(:mygroup)
    @student = @group.students.first
    @mentor = @group.mentors.first
    @current_connection_membership = @group.membership_of(@student)
  end

  def test_after_create_ra
    assert_difference('RecentActivity.count') do
      create_coaching_goal
    end

    ra = RecentActivity.last
    assert_equal ra.action_type, RecentActivityConstants::Type::COACHING_GOAL_CREATION
  end

  def test_after_update_due_date_ra
    coaching_goal = create_coaching_goal
    CoachingGoal.any_instance.stubs(:updating_user).returns(users(:f_mentor))
    assert_difference('RecentActivity.count') do
      coaching_goal.update_attribute(:due_date, 7.days.from_now)
    end

    assert_no_difference('RecentActivity.count') do
      coaching_goal.update_attribute(:title, "New title")
    end

    ra = RecentActivity.last
    assert_equal ra.action_type, RecentActivityConstants::Type::COACHING_GOAL_UPDATED
  end

  def test_after_create_pending_notif
    no_of_notifs = (@group.members - [@mentor]).count
    assert_pending_notifications do
      create_coaching_goal
    end
    
    notif = PendingNotification.last
    assert_equal notif.action_type, RecentActivityConstants::Type::COACHING_GOAL_CREATION
    assert_equal notif.ref_obj_creator.user, @student
  end

end
