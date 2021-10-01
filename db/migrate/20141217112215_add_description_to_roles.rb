class AddDescriptionToRoles< ActiveRecord::Migration[4.2]
  def up
    add_column :roles, :description, :string
  end

  def down
    remove_column :roles, :description
  end
end
