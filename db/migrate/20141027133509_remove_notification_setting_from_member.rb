class RemoveNotificationSettingFromMember< ActiveRecord::Migration[4.2]
  def up
    remove_column :members, :notification_setting
  end

  def down
    add_column :members, :notification_setting
  end
end
