class CreateCalendarSyncNotificationChannels< ActiveRecord::Migration[4.2]
  def change
    ChronusMigrate.ddl_migration do
      create_table :calendar_sync_notification_channels do |t|
        t.string :channel_id, :null => false
        t.string :resource_id, :null => false
        t.string :last_sync_token
        t.datetime :expiration_time, :null => false
        t.datetime :last_sync_time
        t.datetime :last_notification_received_on
        t.timestamps :null => false
      end
    end
  end
end
