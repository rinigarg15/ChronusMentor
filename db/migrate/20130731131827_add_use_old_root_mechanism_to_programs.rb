class AddUseOldRootMechanismToPrograms< ActiveRecord::Migration[4.2]
  def up
    add_column :programs, :can_update_root, :boolean, default: false, null: false
    Organization.update_all('can_update_root=1')
  end

  def down
    remove_column :programs, :can_update_root
  end
end
