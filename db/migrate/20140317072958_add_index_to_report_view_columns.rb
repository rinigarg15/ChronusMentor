class AddIndexToReportViewColumns< ActiveRecord::Migration[4.2]
  def up
    add_index :report_view_columns, [:program_id, :report_type]
  end

  def down
    remove_index :report_view_columns, [:program_id, :report_type]
  end
end
