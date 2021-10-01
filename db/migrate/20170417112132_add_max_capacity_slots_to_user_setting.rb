class AddMaxCapacitySlotsToUserSetting< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table :user_settings do |m|
        m.add_column :max_meeting_slots, "int(11)"
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table :user_settings do |m|
        m.remove_column :max_meeting_slots
      end
    end
  end
end
