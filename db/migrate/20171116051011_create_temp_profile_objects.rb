class CreateTempProfileObjects< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      create_table :temp_profile_objects do |t|
      	t.integer :ref_obj_id
      	t.string :ref_obj_type
        t.timestamps null: false
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      drop_table :temp_profile_objects
    end
  end
end
