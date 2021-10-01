class RemoveViewMentoringCalendarRoleForAdmins< ActiveRecord::Migration[4.2]
  def up
    ActiveRecord::Base.transaction do
      permission_id = Permission.find_by(name: "view_mentoring_calendar").try(:id)
      admin_roles = Role.where(:name => RoleConstants::ADMIN_NAME).includes(:role_permissions, :permissions, :program)
      admin_roles.each do |role| 
        role.role_permissions.where(:permission_id => permission_id).destroy_all
        puts "#{role.program.name}'s permission removed"
      end
      raise "All Permissions where not removed" unless admin_roles.collect{|role| role.role_permissions.where(:permission_id => permission_id)}.flatten.size == 0
    end
  end
end
