class FixColumnName< ActiveRecord::Migration[4.2]
  def up
  	rename_column :programs, :full_import_enabled, :linkedin_full_import_enabled
  end

  def down
  end
end
