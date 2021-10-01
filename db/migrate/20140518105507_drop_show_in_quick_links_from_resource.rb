class DropShowInQuickLinksFromResource< ActiveRecord::Migration[4.2]
  def change
    remove_column :resources, :show_in_quick_links
  end
end
