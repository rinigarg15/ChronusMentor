class AddAccountNameToPrograms< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :account_name, :string
  end
end
