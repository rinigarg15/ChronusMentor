class RemoveCanManageInboxNotificationFromNotificationSetting< ActiveRecord::Migration[4.2]
  def up
    remove_column :notification_settings, :can_manage_inbox_notification
  end

  def down
    add_column :notification_settings, :can_manage_inbox_notification, :boolean, default: false
  end
end
