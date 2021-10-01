class MoveJoinDirectlyValuesToJoinDirectlyWithSso< ActiveRecord::Migration[4.2]
  def up
    ActiveRecord::Base.transaction do
    	add_column :membership_requests, :joined_directly, :boolean, :default => false
    	add_column :roles, :join_directly_only_with_sso, :boolean
    	Program.active.includes(:roles).each do |program|
  	  	program.roles.each do |role|
  	  		if role.join_directly?
  	  			role.update_attributes(:join_directly_only_with_sso => true, :join_directly => false, :membership_request => false)
  	  		end
  	  	end
  	  end
    end
  end

  def down
  end
end
