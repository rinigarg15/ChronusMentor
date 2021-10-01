class ChangeDefaultConnMembershipId< ActiveRecord::Migration[4.2]
  def change
  	change_column :connection_private_notes, :connection_membership_id, :integer, :null => true
  end
end
