class AddRoleIdToAdminView< ActiveRecord::Migration[4.2]
  def change
    add_column :admin_views, :role_id, :integer
    add_index :admin_views, :role_id
  end
end
