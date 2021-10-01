class AddEnabledToAuthConfigs< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table AuthConfig.table_name do |t|
        t.add_column :enabled, "tinyint(1) DEFAULT '1' NOT NULL"
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table AuthConfig.table_name do |t|
        t.remove_column :enabled
      end
    end
  end
end