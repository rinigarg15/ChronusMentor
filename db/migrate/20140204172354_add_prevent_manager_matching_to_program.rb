class AddPreventManagerMatchingToProgram< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :prevent_manager_matching, :boolean, :default => false
  end
end
