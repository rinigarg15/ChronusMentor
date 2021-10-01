class CreateTableAbstractPreference < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      create_table :abstract_preferences do |t|
        t.integer :preference_marker_user_id, null: false, index: true
        t.integer :preference_marked_user_id, null: false, index: true
        t.string :type, null: false
        t.timestamps null: false
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      drop_table :abstract_preferences
    end
  end
end
