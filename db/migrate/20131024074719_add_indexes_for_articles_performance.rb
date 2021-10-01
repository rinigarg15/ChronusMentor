class AddIndexesForArticlesPerformance< ActiveRecord::Migration[4.2]
  def up
    add_index :tags, :name
    add_index :article_list_items, :article_content_id
    add_index :comments, :article_publication_id
  end

  def down
    remove_index :tags, :name
    remove_index :article_list_items, :article_content_id
    remove_index :comments, :article_publication_id
  end
end
