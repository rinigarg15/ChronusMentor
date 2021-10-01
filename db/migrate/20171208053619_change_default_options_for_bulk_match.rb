class ChangeDefaultOptionsForBulkMatch< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table :bulk_matches do |m|
        m.change_column_default(:show_drafted, MigrationConstants::FALSE)
        m.change_column_default(:show_published, MigrationConstants::FALSE)
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table :bulk_matches do |m|
        m.change_column_default(:show_drafted, MigrationConstants::TRUE)
        m.change_column_default(:show_published, MigrationConstants::TRUE)
      end
    end
  end
end
