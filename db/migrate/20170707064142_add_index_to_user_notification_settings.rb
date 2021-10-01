class AddIndexToUserNotificationSettings< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table :user_notification_settings do |t|
        t.add_index :user_id
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table :user_notification_settings do |t|
        t.remove_index :user_id
      end
    end
  end
  
end