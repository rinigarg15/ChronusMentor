class RemoveGpAlertReceievedFromMembers< ActiveRecord::Migration[4.2]
  def up
  	remove_column :members, :gp_alert_recieved  	
  end

  def down
  	add_column :members, :gp_alert_recieved, :boolean
  end
end
