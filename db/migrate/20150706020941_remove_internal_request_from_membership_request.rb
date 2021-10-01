class RemoveInternalRequestFromMembershipRequest< ActiveRecord::Migration[4.2]
  def change
    remove_column :membership_requests, :internal_request
  end
end