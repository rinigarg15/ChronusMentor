class CreateChronusVersions < ActiveRecord::Migration[4.2]
  TEXT_BYTES = 1_073_741_823
  def up
    ChronusMigrate.ddl_migration do
      create_table :chronus_versions do |t|
        t.string   :item_type, {null: false, limit: UTF8MB4_VARCHAR_LIMIT}
        t.integer  :item_id,   null: false
        t.string   :event,     null: false
        t.string   :whodunnit
        t.text     :object, limit: TEXT_BYTES
        t.text     :object_changes, limit: TEXT_BYTES
        t.timestamps null: false
      end
      add_index :chronus_versions, [:item_id, :item_type]
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      drop_table :chronus_versions
    end
  end
end
