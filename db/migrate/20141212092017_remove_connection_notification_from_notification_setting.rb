class RemoveConnectionNotificationFromNotificationSetting< ActiveRecord::Migration[4.2]
  def up
    remove_column :notification_settings, :connection_notification
  end

  def down
    add_column :notification_settings, :connection_notification, :integer, default: 1 # => MentoringAreaConstants::NotifySetting::DAILY_DIGEST
  end
end
