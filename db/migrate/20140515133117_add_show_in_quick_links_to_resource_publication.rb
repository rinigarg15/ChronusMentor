class AddShowInQuickLinksToResourcePublication< ActiveRecord::Migration[4.2]
  def change
    add_column :resource_publications, :show_in_quick_links, :boolean, :default => false
  end
end
