class AddIndicesForHomePagePerformance< ActiveRecord::Migration[4.2]
  def up
    add_index :posts, :published
  end

  def down
    remove_index :posts, :published
  end
end
