class AddLeaveConnectionToProgram< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :allow_users_to_leave_connection, :boolean, :default => false
  end
end
