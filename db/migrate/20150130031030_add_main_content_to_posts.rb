class AddMainContentToPosts< ActiveRecord::Migration[4.2]
  def up
    change_table :posts do |t|
      t.boolean :main_content, :default => false
    end
    Post.update_all ["main_content = ?", true]
  end
 
  def down
    remove_column :posts, :main_content
  end
end
