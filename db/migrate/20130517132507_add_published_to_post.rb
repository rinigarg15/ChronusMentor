class AddPublishedToPost< ActiveRecord::Migration[4.2]
  def change
    add_column :posts, :published, :boolean, default: true
  end
end
