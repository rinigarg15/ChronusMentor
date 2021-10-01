class AddPositionToReportSectionsAndReportMetrics< ActiveRecord::Migration[4.2]
  def change
    add_column :report_sections, :position, :integer, default: 1000
    add_column :report_metrics, :position, :integer, default: 1000
  end
end
