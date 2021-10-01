class RemoveReportTypeFromReportSections< ActiveRecord::Migration[4.2]
  def up
    remove_index :report_sections, [:program_id, :report_type]
    add_index :report_sections, :program_id
    remove_column :report_sections, :report_type
  end

  def down
    add_column :report_sections, :report_type, :integer
    remove_index :report_sections, :program_id
    add_index :report_sections, [:program_id, :report_type]
  end
end
