class AddAvailabiltySettingsToCalendarSetting< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table :calendar_settings do |m|
        m.add_column :max_pending_meeting_requests_for_mentee, "int(11) DEFAULT 5"
        m.add_column :max_meetings_for_mentee, "int(11)"
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table :calendar_settings do |m|
        m.remove_column :max_pending_meeting_requests_for_mentee
        m.remove_column :max_meetings_for_mentee
      end
    end
  end
end
