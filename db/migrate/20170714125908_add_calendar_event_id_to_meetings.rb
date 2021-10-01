class AddCalendarEventIdToMeetings< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table Meeting.table_name do |t|
        t.add_column :calendar_event_id, "varchar(1024)"
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table Meeting.table_name do |t|
        t.remove_column :calendar_event_id
      end
    end
  end
end
