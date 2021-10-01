class AddNotificationSettingToConnectionMembership< ActiveRecord::Migration[4.2]
  def change
    add_column :connection_memberships, :notification_setting, :integer, :default => 0 # previously MentoringAreaConstants::NotifySetting::WEEKLY_DIGEST
  end
end
