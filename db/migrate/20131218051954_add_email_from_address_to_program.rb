class AddEmailFromAddressToProgram< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :email_from_address, :string
  end
end
