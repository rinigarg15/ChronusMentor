class CoachingGoalActivityObserver < ActiveRecord::Observer
  def after_create(coaching_goal_activity)
    append_to_recent_activity(coaching_goal_activity)

    initiator = coaching_goal_activity.initiator
    progress_value_updated = coaching_goal_activity.saved_change_to_progress_value? ? coaching_goal_activity.progress_value : nil
    self.class.send_later(:send_coaching_goal_activity_creation_emails, coaching_goal_activity, progress_value_updated, initiator)
  end

  private

  def append_to_recent_activity(coaching_goal_activity)
    RecentActivity.create!(
      :programs => [coaching_goal_activity.coaching_goal.group.program],
      :ref_obj => coaching_goal_activity,
      :action_type => RecentActivityConstants::Type::COACHING_GOAL_ACTIVITY_CREATION,
      :member => coaching_goal_activity.initiator.member,
      :target => RecentActivityConstants::Target::ALL
    )
  end

  def self.send_coaching_goal_activity_creation_emails(coaching_goal_activity, progress_value_updated, initiator)
    group = coaching_goal_activity.coaching_goal.group
    members_to_send = group.members - [initiator]
    members_to_send.each do |member|
      membership = group.membership_of(member)
      membership.send_email(coaching_goal_activity, RecentActivityConstants::Type::COACHING_GOAL_ACTIVITY_CREATION, initiator, progress_value_updated)
    end
  end
end