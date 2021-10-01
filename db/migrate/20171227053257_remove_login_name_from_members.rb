class RemoveLoginNameFromMembers< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table Member.table_name do |t|
        t.remove_column :login_name
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table Member.table_name do |t|
        t.add_column :login_name, "varchar(191)"
        t.add_index :login_name
      end
    end
  end
end