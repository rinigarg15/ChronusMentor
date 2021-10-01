class AddPreferenceStringToExplicitUserPreferences < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table :explicit_user_preferences do |t|
        t.add_column :preference_string, "text"
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table :explicit_user_preferences do |t|
        t.remove_column :preference_string
      end
    end
  end
end
