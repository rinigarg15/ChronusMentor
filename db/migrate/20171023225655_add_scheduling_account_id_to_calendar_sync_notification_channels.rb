class AddSchedulingAccountIdToCalendarSyncNotificationChannels< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table CalendarSyncNotificationChannel.table_name do |table|
        table.add_column :scheduling_account_id, "int(11)"
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table CalendarSyncNotificationChannel.table_name do |table|
        table.remove_column :scheduling_account_id
      end
    end
  end
end
