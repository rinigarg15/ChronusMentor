class AddAdminViewToResourcePublication < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table :resource_publications do |r|
        r.add_column :admin_view_id, "int(11)"
        r.add_index :admin_view_id
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table :resource_publications do |r|
        r.remove_column :admin_view_id
        r.remove_index :admin_view_id
      end
    end
  end
end
