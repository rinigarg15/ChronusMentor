class AddTypeToAdminViews< ActiveRecord::Migration[4.2]
  def change
    add_column :admin_views, :type, :string, default: AdminView.name
  end
end
