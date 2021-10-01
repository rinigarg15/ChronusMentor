class AddRoleIdToGroupViewColumns< ActiveRecord::Migration[4.2]
  def change
    add_column :group_view_columns, :role_id, :integer
  end
end
