class RemoveAllowsLoggedInPagesFromPrograms< ActiveRecord::Migration[4.2]
  def up
    remove_column :programs, :allows_logged_in_pages
  end

  def down
    add_column :programs, :allows_logged_in_pages, :boolean, :default => false
  end
end
