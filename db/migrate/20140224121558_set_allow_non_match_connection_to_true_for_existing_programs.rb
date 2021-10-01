class SetAllowNonMatchConnectionToTrueForExistingPrograms< ActiveRecord::Migration[4.2]
  def up
    Program.update_all :allow_non_match_connection => true
  end

  def down
    Program.update_all :allow_non_match_connection => false
  end
end
