class AddMultipleTemplatesToFeatures< ActiveRecord::Migration[4.2]
  def change
    Feature.create_default_features if Feature.count > 0
  end
end
