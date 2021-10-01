class AddSettingsOptionForBulkMatch< ActiveRecord::Migration[4.2]
  def change
    add_column :bulk_matches, :show_drafted, :boolean, :default => true
    add_column :bulk_matches, :show_published, :boolean, :default => true
    add_column :bulk_matches, :sort_value, :string
    add_column :bulk_matches, :sort_order, :string
  end
end