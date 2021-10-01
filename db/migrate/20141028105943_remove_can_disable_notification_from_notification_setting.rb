class RemoveCanDisableNotificationFromNotificationSetting< ActiveRecord::Migration[4.2]
  def up
    remove_column :notification_settings, :can_disable_notifications
  end

  def down
    add_column :notification_settings, :can_disable_notifications, :boolean, default: false
  end
end
