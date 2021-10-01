class RemoveLinkedinFullImportEnabledFromPrograms< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table AbstractProgram.table_name do |t|
        t.remove_column :linkedin_full_import_enabled
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table AbstractProgram.table_name do |t|
        t.add_column :linkedin_full_import_enabled, :boolean, default: false
      end
    end
  end
end
