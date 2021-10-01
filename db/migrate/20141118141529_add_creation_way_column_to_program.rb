class AddCreationWayColumnToProgram< ActiveRecord::Migration[4.2]
  def change
  	add_column :programs, :creation_way, :integer
  end
end
