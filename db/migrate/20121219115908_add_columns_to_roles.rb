class AddColumnsToRoles< ActiveRecord::Migration[4.2]
  def up
    add_column :roles, :default, :integer
    add_column :roles, :join_directly, :boolean
    add_column :roles, :membership_request, :boolean
    add_column :roles, :invitation, :boolean	  
  end

  def down
  	remove_column :roles, :default
    remove_column :roles, :join_directly
    remove_column :roles, :membership_request
    remove_column :roles, :invitation
  end
end