class AddProjectRequestPermissions< ActiveRecord::Migration[4.2]
  def change
    if Permission.count > 0
      Permission.create_default_permissions

      Program.active.includes(:roles).each do |program|
        if program.project_based?
          program.roles.each do |role|
            Array(RoleConstants::PROJECT_REQUEST_PERMISSIONS[role.name]).each do |permission_name|
              role.add_permission(permission_name)
            end
          end
        end
      end
    end
  end
end
