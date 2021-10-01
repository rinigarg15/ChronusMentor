class AddLogFileColumnToDataImport< ActiveRecord::Migration[4.2]
  def change
    add_column(:data_imports, "log_file_file_name", :string)
    add_column(:data_imports, "log_file_content_type", :string)
    add_column(:data_imports, "log_file_file_size", :integer)
    add_column(:data_imports, "log_file_updated_at", :datetime)
  end
end
