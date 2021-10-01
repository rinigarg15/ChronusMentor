class CoachingGoalObserver < ActiveRecord::Observer

  def after_create(coaching_goal)
    creator = coaching_goal.creator
    append_to_recent_activity(coaching_goal, RecentActivityConstants::Type::COACHING_GOAL_CREATION, creator)
    self.class.send_later(:send_coaching_goal_creation_emails, coaching_goal, creator)
  end

  def after_update(coaching_goal)
    if coaching_goal.saved_change_to_due_date?
      append_to_recent_activity(coaching_goal, RecentActivityConstants::Type::COACHING_GOAL_UPDATED, coaching_goal.updating_user)
    end
  end

  private

  def append_to_recent_activity(coaching_goal, ra_type, user)
    RecentActivity.create!(
      :programs => [coaching_goal.group.program],
      :ref_obj => coaching_goal,
      :action_type => ra_type,
      :member => user.member,
      :target => RecentActivityConstants::Target::ALL
    )
  end

  def self.send_coaching_goal_creation_emails(coaching_goal, creator)
    group = coaching_goal.group
    members_to_send = group.members - [creator]
    members_to_send.each do |member|
      membership = group.membership_of(member)
      membership.send_email(coaching_goal, RecentActivityConstants::Type::COACHING_GOAL_CREATION, creator)
    end
  end


end