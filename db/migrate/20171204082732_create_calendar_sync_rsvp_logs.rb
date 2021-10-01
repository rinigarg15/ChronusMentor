class CreateCalendarSyncRsvpLogs< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      create_table :calendar_sync_rsvp_logs do |t|
        t.integer :notification_id
        t.string :event_id
        t.string :recurring_event_id
        t.text :rsvp_details
        t.timestamps null: false
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      drop_table :calendar_sync_rsvp_logs
    end
  end
end
