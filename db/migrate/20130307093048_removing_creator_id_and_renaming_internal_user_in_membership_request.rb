class RemovingCreatorIdAndRenamingInternalUserInMembershipRequest< ActiveRecord::Migration[4.2]
  def change
    remove_column :membership_requests, :creator_id
    rename_column :membership_requests, :internal_user, :internal_request
    rename_column :membership_requests, :user_id, :admin_id
  end
end
