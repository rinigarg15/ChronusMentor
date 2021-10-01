class AddProfileCompletionSidebarToUsers< ActiveRecord::Migration[4.2]
  def change
    add_column :users, :hide_profile_completion_bar, :boolean, :default => false
  end
end
