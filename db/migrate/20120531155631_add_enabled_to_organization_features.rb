class AddEnabledToOrganizationFeatures< ActiveRecord::Migration[4.2]
  def change
    add_column :organization_features, :enabled, :boolean, :default => true
  end
end
