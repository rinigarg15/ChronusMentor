class AddStickyToTopics< ActiveRecord::Migration[4.2]
  def change
    add_column :topics, :sticky_position, :integer, default: 0
    if Feature.count > 0
      Feature.create_default_features
    end
  end
end
