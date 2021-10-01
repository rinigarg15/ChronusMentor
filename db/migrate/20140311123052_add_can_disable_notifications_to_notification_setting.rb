class AddCanDisableNotificationsToNotificationSetting< ActiveRecord::Migration[4.2]
  def up
    add_column :notification_settings, :can_disable_notifications, :boolean, default: false
    NotificationSetting.update_all(:can_disable_notifications => true)
  end

  def down
    remove_column :notification_settings, :can_disable_notifications
  end
end
