class RemoveExternalUserColumn< ActiveRecord::Migration[4.2]
  def up
    remove_column :membership_requests, :external_user
    remove_column :members, :external_user
    remove_column :program_invitations, :system
  end

  def down
    add_column :membership_requests, :external_user, :boolean
    add_column :members, :external_user, :boolean
    add_column :program_invitations, :system, :boolean
  end
end
