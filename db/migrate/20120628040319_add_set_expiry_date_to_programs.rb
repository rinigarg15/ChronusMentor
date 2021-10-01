class AddSetExpiryDateToPrograms< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :allow_to_change_connection_expiry_date, :boolean, :default => false
  end
end
