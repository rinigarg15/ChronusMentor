class CreateTempMembers< ActiveRecord::Migration[4.2]
  def change
    ChronusMigrate.ddl_migration do
      create_table :temp_members do |t|
        t.integer :member_id
        t.integer :batch # We process the data in batches of 1000 in parallel processes. This column identifies the batch.
        t.timestamps null: true
      end
    end
  end
end
