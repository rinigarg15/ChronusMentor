class UpdateRolesDescription< ActiveRecord::Migration[4.2]
  def up
    change_column :roles, :description, :text
  end

  def down
    change_column :roles, :description, :string
  end
end
