class AddShowBothRoleOptionToProgram< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :show_both_role_option, :boolean, :default => false
  end
end
