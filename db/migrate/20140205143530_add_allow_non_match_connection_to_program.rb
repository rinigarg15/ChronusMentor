class AddAllowNonMatchConnectionToProgram< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :allow_non_match_connection, :boolean, :default => true
  end
end
