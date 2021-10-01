class RemoveCreatorColumn< ActiveRecord::Migration[4.2]
  def change
    ActiveRecord::Base.transaction do
      PendingNotification.where(:action_type => RecentActivityConstants::Type::COACHING_GOAL_CREATION).each do |notif|
        update_notif_attr(notif, true)
      end
      remove_column :coaching_goals, :creator_id
      PendingNotification.where(:action_type => RecentActivityConstants::Type::COACHING_GOAL_ACTIVITY_CREATION).each do |notif|
        update_notif_attr(notif, false)
      end
      remove_column :coaching_goal_activities, :initiator_id
    end
  end

  def update_notif_attr(notif, is_goal)
    creator_or_initiator = is_goal ? Connection::Membership.find(notif.ref_obj.creator_id) : Connection::Membership.find(notif.ref_obj.initiator_id)
    notif.update_attributes!(:initiator_id => creator_or_initiator.user_id)
  end
end
