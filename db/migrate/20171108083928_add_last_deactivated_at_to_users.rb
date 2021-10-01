class AddLastDeactivatedAtToUsers< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table User.table_name do |table|
        table.add_column :last_deactivated_at, "datetime"
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table User.table_name do |table|
        table.remove_column :last_deactivated_at
      end
    end
  end
end