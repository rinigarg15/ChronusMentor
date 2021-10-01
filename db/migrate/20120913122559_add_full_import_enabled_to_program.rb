class AddFullImportEnabledToProgram< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :full_import_enabled, :boolean, :default => false, :null => false
  end
end
