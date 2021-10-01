class AddFindNewProjectPermissions< ActiveRecord::Migration[4.2]
  def change
    if Permission.count > 0
      Permission.create_default_permissions
      Program.where(engagement_type: Program::EngagementType::PROJECT_BASED).includes(:roles).find_each do |program|
        say program.name, true
        program.roles.select{|role| role.name == RoleConstants::MENTOR_NAME || role.name == RoleConstants::STUDENT_NAME}.each do |role|
          role.add_permission("view_find_new_projects")
        end
      end
    end
  end
end
