class AddAllowsLoggedInPagesToPrograms< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :allows_logged_in_pages, :boolean, :default => false
  end
end
