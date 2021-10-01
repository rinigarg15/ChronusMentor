class AddOrientationTypeToBulkMatch < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table BulkMatch.table_name do |table|
        table.add_column :orientation_type, "int(11) DEFAULT #{BulkMatch::OrientationType::MENTEE_TO_MENTOR}"
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table BulkMatch.table_name do |table|
        table.remove_column :orientation_type
      end
    end
  end
end