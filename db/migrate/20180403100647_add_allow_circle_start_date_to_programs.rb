class AddAllowCircleStartDateToPrograms < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table Program.table_name do |table|
        table.add_column :allow_circle_start_date, "TINYINT(1) DEFAULT 0"
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table Program.table_name do |table|
        table.remove_column :allow_circle_start_date
      end
    end
  end
end
