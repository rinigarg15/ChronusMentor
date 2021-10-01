class AddBulkMatchFeature< ActiveRecord::Migration[4.2]
  def change
    if Feature.count > 0
      Feature.create_default_features
    end
  end
end