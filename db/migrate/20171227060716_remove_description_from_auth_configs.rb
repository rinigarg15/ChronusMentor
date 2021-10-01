class RemoveDescriptionFromAuthConfigs< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table AuthConfig.table_name do |t|
        t.remove_column :description
      end

      Lhm.change_table AuthConfig::Translation.table_name do |t|
        t.remove_column :description
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table AuthConfig.table_name do |t|
        t.add_column :description, "text"
      end

      Lhm.change_table AuthConfig::Translation.table_name do |t|
        t.add_column :description, "text"
      end
    end
  end
end