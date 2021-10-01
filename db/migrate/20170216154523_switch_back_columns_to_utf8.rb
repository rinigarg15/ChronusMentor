class SwitchBackColumnsToUtf8< ActiveRecord::Migration[4.2]
  # utf8mb4 tables can index only first 191 characters. The following columns had data more than 191 characters while upgrading DB from utf8 to utf8mb4.
  # Hence these columns were retained in utf8.
  def up
    migrator = MigrateDBFromUTF8ToUTF8MB4.new(migrate_problematic_columns_only: true)
    migrator.migrate
    Lhm.cleanup(true)
  end

  def down
  end
end