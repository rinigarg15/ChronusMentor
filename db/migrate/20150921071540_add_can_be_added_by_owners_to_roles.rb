class AddCanBeAddedByOwnersToRoles< ActiveRecord::Migration[4.2]
  def up
    add_column :roles, :can_be_added_by_owners, :boolean, default: true 
  end

  def down
    remove_column :roles, :can_be_added_by_owners, :boolean, default: true
  end
end
