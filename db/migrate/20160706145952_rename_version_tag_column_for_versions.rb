class RenameVersionTagColumnForVersions< ActiveRecord::Migration[4.2]
  def up
    remove_index :versions, :version_tag
    rename_column :versions, :version_tag, :tag
    add_index :versions, :tag
  end

  def down
    remove_index :versions, :tag
    rename_column :versions, :tag, :version_tag
    add_index :versions, :version_tag
  end
end
