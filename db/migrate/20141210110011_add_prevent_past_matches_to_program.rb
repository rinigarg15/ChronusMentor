class AddPreventPastMatchesToProgram< ActiveRecord::Migration[4.2]
  def up
    add_column :programs, :prevent_past_mentor_matching, :boolean, :default => false
  end

  def down
    remove_column :programs, :prevent_past_mentor_matching
  end
end
