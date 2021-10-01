class CreateLocationLookups< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      create_table :location_lookups do |t|
        t.string :address_text, limit: UTF8MB4_VARCHAR_LIMIT
        t.integer :location_id
        t.timestamps null: false
      end

      Lhm.change_table :location_lookups do |t|
        t.add_index :location_id
        t.add_index :address_text
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      drop_table :location_lookups
    end
  end
end
