class CreateUserNotificationSettings< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      create_table :user_notification_settings do |t|
        t.string :notification_setting_name
        t.boolean :disabled
        t.integer :user_id
        t.timestamps null: false
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      drop_table :user_notification_settings
    end
  end
end
