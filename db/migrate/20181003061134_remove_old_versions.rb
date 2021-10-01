class RemoveOldVersions < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.ddl_migration do
      drop_table :versions_old
    end
  end

  def down
    # do nothing
  end
end
