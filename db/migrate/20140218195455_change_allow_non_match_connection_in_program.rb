class ChangeAllowNonMatchConnectionInProgram< ActiveRecord::Migration[4.2]
  def up
    change_column :programs, :allow_non_match_connection, :boolean, :default => false
  end
  def down
    change_column :programs, :allow_non_match_connection, :boolean, :default => true
  end
end
