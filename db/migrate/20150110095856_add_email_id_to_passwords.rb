class AddEmailIdToPasswords< ActiveRecord::Migration[4.2]
  def up
    add_column :passwords, :email_id, :string
  end

  def down
    remove_column :passwords, :email_id
  end
end