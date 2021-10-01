class ChangeVersionsTable < ActiveRecord::Migration[4.2]
  def change
    ChronusMigrate.ddl_migration do
      rename_table :versions, :versions_old
    end
  end
end
