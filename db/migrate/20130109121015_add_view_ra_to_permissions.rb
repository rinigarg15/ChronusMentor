class AddViewRaToPermissions< ActiveRecord::Migration[4.2]
  def change
  	if Permission.count > 0
      Permission.create_default_permissions
	    Role.default.each do |role|
	    	role.add_permission('view_ra')
	    end
    end
  end
end