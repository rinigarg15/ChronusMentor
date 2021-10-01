class AddPublishedAtToGroup< ActiveRecord::Migration[4.2]
  def change
    add_column :groups, :published_at, :datetime
    ActiveRecord::Base.connection.execute("UPDATE groups SET published_at=created_at")
    if Feature.count > 0
      Feature.create_default_features
    end
  end
end
