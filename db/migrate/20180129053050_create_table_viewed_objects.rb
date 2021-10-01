class CreateTableViewedObjects  < ActiveRecord::Migration[4.2]

  def up
    ChronusMigrate.ddl_migration do
      create_table :viewed_objects do |t|
        t.references :ref_obj, polymorphic: true, index: true
        t.references :user, index: true
        t.timestamps null: false
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      drop_table :viewed_objects
    end
  end

end