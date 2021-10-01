class AddShowInQuickLinksToResources< ActiveRecord::Migration[4.2]
  def change
    add_column :resources, :show_in_quick_links, :boolean, :default => true
  end
end
