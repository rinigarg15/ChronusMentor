class CreateTempProfileAnswerLocation < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      create_table :temp_profile_answer_locations do |t|
        t.integer :profile_answer_id
        t.integer :location_id
        t.string :full_address
        t.timestamps
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      drop_table :temp_profile_answer_locations
    end
  end
end
