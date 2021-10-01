class SetNewColumnValuesForRoles< ActiveRecord::Migration[4.2]
  def up
  	ActiveRecord::Base.transaction do
	  	Program.active.includes(:roles).each do |program|
		    program.roles.each do |role|
		    	case role.name
	    		when RoleConstants::ADMIN_NAME
			  		role.default = RoleConstants::Default::ADMIN
			  		role.membership_request = false
			  		role.invitation = true
			  	when RoleConstants::MENTOR_NAME
			  		role.default = RoleConstants::Default::MENTOR
			  		role.membership_request = program.allow_membership_requests
						role.invitation = true
			  	when RoleConstants::STUDENT_NAME
			  		role.default = RoleConstants::Default::STUDENT
			  		role.membership_request = program.allow_membership_requests
			  		role.invitation = true
			  	when RoleConstants::GUEST_MENTOR_NAME
			  		role.membership_request = false
			  		role.invitation = false
			  	when RoleConstants::COMMITTEE_MEMBER_NAME
			  		role.membership_request = false
			  		role.invitation = true
			  	when RoleConstants::BOARD_OF_ADVISOR_NAME
			  		role.membership_request = false
			  		role.invitation = false
			  	else
			  		puts "Unknown role #{role.name} found in #{program.name} program"
			  	end
			  	role.join_directly = (program.attributes["roles_to_join_directly"].present? && program.attributes["roles_to_join_directly"].include?(role.name))
			  	role.save!
			  	puts "#{role.name} done -- #{role.join_directly}, #{role.membership_request}, #{role.invitation}"
			  end
			  puts "Migration of roles in #{program.name} done"
			  puts "=========================================="
			end
			remove_column :programs, :allow_membership_requests
  		remove_column :programs, :roles_to_join_directly
		end
  end

  def down
  end
end