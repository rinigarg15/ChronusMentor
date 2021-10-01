class AddStartDateToGroups < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table Group.table_name do |table|
        table.add_column :start_date, "datetime"
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table Group.table_name do |table|
        table.remove_column :start_date
      end
    end
  end
end
