class RenameColumnAdminIdToTerminatorIdInGroup< ActiveRecord::Migration[4.2]
  def change
    rename_column :groups, :admin_id, :terminator_id
  end
end
