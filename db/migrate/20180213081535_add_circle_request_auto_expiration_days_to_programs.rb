class AddCircleRequestAutoExpirationDaysToPrograms < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table Program.table_name do |table|
        table.add_column :circle_request_auto_expiration_days, "int(11)"
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table Program.table_name do |table|
        table.remove_column :circle_request_auto_expiration_days
      end
    end
  end
end
