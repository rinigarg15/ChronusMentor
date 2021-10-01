class AddFluidLayoutToPrograms< ActiveRecord::Migration[4.2]
  def change
  	add_column :programs, :fluid_layout, :boolean, :default => true
  	remove_column :programs, :logo_file_name
  	remove_column :programs, :logo_content_type
  	remove_column :programs, :logo_file_size
  	remove_column :programs, :logo_updated_at
  end
end
