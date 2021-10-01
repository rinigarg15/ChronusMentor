class AddOwnerToConnectionMembership< ActiveRecord::Migration[4.2]
  def change
    add_column :connection_memberships, :owner, :boolean, default: false
  end
end
