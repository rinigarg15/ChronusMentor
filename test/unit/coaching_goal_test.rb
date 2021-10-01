require_relative './../test_helper.rb'

class CoachingGoalTest < ActiveSupport::TestCase

  def test_validations
    coaching_goal = CoachingGoal.new
    assert_false coaching_goal.valid?
    assert_equal(["can't be blank"], coaching_goal.errors[:title])
    assert_equal(["can't be blank"], coaching_goal.errors[:group])
  end
  
  def test_in_progress_overdue
    group = groups(:mygroup)
    coaching_goal = create_coaching_goal
    CoachingGoal.any_instance.stubs(:updating_user).returns(users(:f_mentor))
    assert_nil coaching_goal.due_date
    assert coaching_goal.in_progress?
    assert_false coaching_goal.overdue?
    assert_false coaching_goal.completed?

    coaching_goal.update_attributes!(:due_date => (Time.now.utc + 2.days).to_date)
    assert coaching_goal.in_progress?
    assert_false coaching_goal.overdue?
    assert_false coaching_goal.completed?

    coaching_goal.update_attributes!(:due_date => (Time.now.utc - 2.days).to_date)
    assert_false coaching_goal.in_progress?
    assert coaching_goal.overdue?
    assert_false coaching_goal.completed?

    coaching_goal.update_attributes!(:due_date => (Time.now.utc - 2.days).to_date)
    create_coaching_goal_activity(coaching_goal, :progress_value => "100", :initiator => users(:f_mentor))
    assert_false coaching_goal.in_progress?
    assert_false coaching_goal.overdue?    
    assert coaching_goal.completed?
  end

  def test_completed_percentage
    group = groups(:mygroup)
    initiator = users(:f_mentor)
    coaching_goal = create_coaching_goal
    assert_equal CoachingGoalActivity::START_PROGRESS_VALUE, coaching_goal.completed_percentage
    coaching_goal_activity = create_coaching_goal_activity(coaching_goal, :progress_value => 72, :initiator => initiator)
    assert_equal 72, coaching_goal.completed_percentage

    time_traveller(2.days.from_now) do
      coaching_goal_activity = create_coaching_goal_activity(coaching_goal, :progress_value => 60, :initiator => initiator)
    end

    assert_equal 60, coaching_goal.completed_percentage

    time_traveller(4.days.from_now) do
      coaching_goal_activity = create_coaching_goal_activity(coaching_goal, :message => "sample", :initiator => initiator)
    end  

    assert_equal 60, coaching_goal.reload.completed_percentage
  end

  def test_last_coaching_goal_activity
    group = groups(:mygroup)
    initiator = users(:f_mentor)
    coaching_goal = create_coaching_goal
    assert_nil coaching_goal.last_coaching_goal_activity
    coaching_goal_activity = create_coaching_goal_activity(coaching_goal, :progress_value => 72, :initiator => initiator)
    assert_equal coaching_goal_activity, coaching_goal.last_coaching_goal_activity

    time_traveller(2.days.from_now) do
      coaching_goal_activity = create_coaching_goal_activity(coaching_goal, :progress_value => 60, :initiator => initiator)
    end

    assert_equal coaching_goal_activity, coaching_goal.last_coaching_goal_activity

    time_traveller(3.days.from_now) do
      coaching_goal_activity1 = create_coaching_goal_activity(coaching_goal, :message => "sample", :initiator => initiator)
    end
    
    coaching_goal_activity2 = nil
    time_traveller(3.days.from_now + 1.minute) do
      coaching_goal_activity2 = create_coaching_goal_activity(coaching_goal, :message => "sample123", :initiator => initiator)
    end

    assert_equal coaching_goal_activity2, coaching_goal.reload.last_coaching_goal_activity
  end

  def test_update_progress
    group = groups(:mygroup)
    connection_membership = groups(:mygroup).membership_of(users(:f_mentor))
    coaching_goal = create_coaching_goal
    assert_equal 0, coaching_goal.reload.completed_percentage

    coaching_goal_activity = coaching_goal.update_progress(connection_membership, 20, "sample")

    assert_equal "sample", coaching_goal_activity.message
    assert_equal 20.0, coaching_goal_activity.progress_value

    coaching_goal_activity = coaching_goal.update_progress(connection_membership, 20, "awesome")

    assert_equal "awesome", coaching_goal_activity.message
    assert_nil coaching_goal_activity.progress_value

    coaching_goal_activity = coaching_goal.update_progress(connection_membership, 30, nil)

    assert_nil coaching_goal_activity.message
    assert_equal 30.0, coaching_goal_activity.progress_value
  end

  def test_pending_notifications_dependence_on_goals_and_activities
    group = groups(:multi_group)
    creator = group.mentors.first
    connection_membership = group.membership_of(creator)
    notif_count = (group.members - [creator]).count

    assert_pending_notifications notif_count do
      create_coaching_goal(:group_id => group.id, :creator => creator)
    end

    coaching_goal = group.coaching_goals.last
    assert_pending_notifications notif_count*2 do
      coaching_goal.update_progress(connection_membership, 20, "sample")
      coaching_goal.update_progress(connection_membership, 30, nil)
    end

    coaching_goal_activity = coaching_goal.coaching_goal_activities.last
    assert_pending_notifications -notif_count do
      coaching_goal_activity.destroy
    end

    assert_equal coaching_goal.coaching_goal_activities.count, 1
    #Destroy of goal should destroy notifs of goal and its activities
    assert_pending_notifications -(notif_count*2) do
      coaching_goal.destroy
    end

    new_mentors = group.mentors - [creator]
    create_coaching_goal(:group_id => group.id, :creator => creator)
    assert_no_difference 'PendingNotification.where(:action_type => RecentActivityConstants::Type::COACHING_GOAL_CREATION).count' do
      group.update_members(new_mentors, group.students)
    end

  end
end
