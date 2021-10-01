class AddTimestampsToLocation < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table Location.table_name do |table|
        table.add_column :created_at, :datetime
        table.add_column :updated_at, :datetime
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table Location.table_name do |table|
        table.remove_column :created_at
        table.remove_column :updated_at
      end
    end
  end
end
