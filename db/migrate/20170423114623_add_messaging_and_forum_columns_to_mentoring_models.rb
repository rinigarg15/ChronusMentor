class AddMessagingAndForumColumnsToMentoringModels< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table MentoringModel.table_name do |t|
        t.add_column :allow_messaging, "tinyint(1) DEFAULT '1' NOT NULL"
        t.add_column :allow_forum, "tinyint(1) DEFAULT '0' NOT NULL"
        t.add_column :forum_help_text, "text"
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table MentoringModel.table_name do |t|
        t.remove_column :allow_messaging
        t.remove_column :allow_forum
        t.remove_column :forum_help_text
      end
    end
  end
end