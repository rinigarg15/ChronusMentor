class AddShowMatchLabelToMatchConfigs< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table MatchConfig.table_name do |table|
        table.add_column :show_match_label, "tinyint(1) DEFAULT '0' NOT NULL"
        table.add_column :prefix, "text"
      end
    end
  end

   def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table MatchConfig.table_name do |table|
        table.remove_column :show_match_label
        table.remove_column :prefix
      end
    end
  end
end
