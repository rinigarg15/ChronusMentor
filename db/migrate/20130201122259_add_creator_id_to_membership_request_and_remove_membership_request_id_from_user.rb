class AddCreatorIdToMembershipRequestAndRemoveMembershipRequestIdFromUser< ActiveRecord::Migration[4.2]
  def change
  	add_column :membership_requests, :creator_id, :integer
  	add_column :membership_requests, :internal_user, :boolean
  	ActiveRecord::Base.connection.execute("update membership_requests m, users u set m.creator_id = u.id where m.id = u.membership_request_id")
  	remove_column :users, :membership_request_id
  end
end
