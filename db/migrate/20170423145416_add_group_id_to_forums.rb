class AddGroupIdToForums< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table Forum.table_name do |t|
        t.add_column :group_id, "int(11)"
        t.add_index :group_id
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table Forum.table_name do |t|
        t.remove_column :group_id
      end
    end
  end
end