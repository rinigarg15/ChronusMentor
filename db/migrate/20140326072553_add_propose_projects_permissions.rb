class AddProposeProjectsPermissions< ActiveRecord::Migration[4.2]
  def change
    Permission.create_default_permissions if Permission.count > 0
  end
end
