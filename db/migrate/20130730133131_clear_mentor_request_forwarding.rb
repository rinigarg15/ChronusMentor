class ClearMentorRequestForwarding< ActiveRecord::Migration[4.2]
  def change
  	ActiveRecord::Base.transaction do
  		remove_column :programs, :connection_requires_mentor_approval
  		remove_column :mentor_requests, :forwarded_mentor_id
  		drop_table :rejection_logs
  		PendingNotification.where(action_type: [30, 31]).destroy_all
  	end
  end
end
