class RemoveOldPendingNotifications< ActiveRecord::Migration[4.2]
  def up
    ActiveRecord::Base.transaction do
      PendingNotification.where("created_at < ?", 10.days.ago).destroy_all
    end
  end

  def down
  end
end
