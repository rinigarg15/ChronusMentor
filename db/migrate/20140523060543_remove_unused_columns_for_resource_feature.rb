class RemoveUnusedColumnsForResourceFeature< ActiveRecord::Migration[4.2]
  def up
  	remove_column :role_resources, :resource_id
  	remove_column :resources, :position
  end

  def down
  	add_column :role_resources, :resource_id, :integer
  	add_column :resources, :position, :integer
  end
end
