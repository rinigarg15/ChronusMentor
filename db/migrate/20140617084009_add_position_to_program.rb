class AddPositionToProgram< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :position, :integer
  end
end
