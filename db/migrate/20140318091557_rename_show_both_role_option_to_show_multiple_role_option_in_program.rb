class RenameShowBothRoleOptionToShowMultipleRoleOptionInProgram< ActiveRecord::Migration[4.2]
  def change
    rename_column :programs, :show_both_role_option, :show_multiple_role_option
  end
end
