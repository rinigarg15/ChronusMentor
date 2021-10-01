class AddInviteRoleToPermissionsForAllRole< ActiveRecord::Migration[4.2]
  def change
  	if Permission.count > 0
      Permission.create_default_permissions
    end
  end
end
