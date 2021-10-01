class AddManagerMatchingLevelToProgram< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :manager_matching_level, :integer, :default => 1
  end
end
