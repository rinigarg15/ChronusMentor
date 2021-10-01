class AddRoleNamesToAnnouncementRecipientRoleRolesWhenNil< ActiveRecord::Migration[4.2]
  def change
  	Program.active.each do |program|
  		non_admin_role_names = program.roles_without_admin_role.collect(&:name)
  		program.announcements.each do |announcement|
  			unless announcement.recipient_roles.present?
  				announcement.recipient_role_names = non_admin_role_names
  				announcement.save!
  			end
  		end  		
  	end
  end
end
