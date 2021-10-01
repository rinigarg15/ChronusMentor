class RemoveAuthConfigIdFromMembers< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table Member.table_name do |t|
        t.remove_column :auth_config_id
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table Member.table_name do |t|
        t.add_column :auth_config_id, "int(11)"
      end
    end
  end
end