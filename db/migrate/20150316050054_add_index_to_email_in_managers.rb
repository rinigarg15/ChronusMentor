class AddIndexToEmailInManagers< ActiveRecord::Migration[4.2]
  def up
    add_index :managers, :email
  end

  def down
    remove_index :managers, :email
  end
end