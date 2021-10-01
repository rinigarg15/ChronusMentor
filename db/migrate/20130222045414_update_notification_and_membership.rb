class UpdateNotificationAndMembership< ActiveRecord::Migration[4.2]
  def change
    PendingNotification.update_all(["ref_obj_creator_type=?", 'User'])
    Connection::Membership.update_all(["last_update_sent_time=?", Time.now])
  end
end
