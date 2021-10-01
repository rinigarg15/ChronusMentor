class AddMaxConnectionsLimitToRoles < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.ddl_migration(has_downtime: false) do
      Lhm.change_table :roles do |t|
        t.add_column :max_connections_limit, "int(11)"
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration(has_downtime: false) do
      Lhm.change_table :roles do |t|
        t.remove_column :max_connections_limit
      end
    end
  end
end