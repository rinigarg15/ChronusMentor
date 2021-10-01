class AddConnectionLimitPermissionToProgram< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :connection_limit_permission, :integer, :limit => 1, :default => Program::ConnectionLimit::BOTH
  end
end
