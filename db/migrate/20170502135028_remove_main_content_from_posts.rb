class RemoveMainContentFromPosts< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration do
      Lhm.change_table Post.table_name do |t|
        t.remove_column :main_content
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table Post.table_name do |t|
        t.add_column :main_content, "tinyint(1) DEFAULT '0'"
      end
    end
  end
end