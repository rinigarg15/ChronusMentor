class AddTimeZoneToMeetings< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table Meeting.table_name do |table|
        table.add_column :time_zone, "varchar(100)"
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table Meeting.table_name do |table|
        table.remove_column :time_zone
      end
    end
  end
end
