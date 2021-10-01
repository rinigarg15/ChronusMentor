class AddCanManageInboxNotificationToNotificationSetting< ActiveRecord::Migration[4.2]
  def up
    add_column :notification_settings, :can_manage_inbox_notification, :boolean, default: false
    NotificationSetting.update_all(:can_manage_inbox_notification => true)
  end

  def down
    remove_column :notification_settings, :can_manage_inbox_notification
  end
end
