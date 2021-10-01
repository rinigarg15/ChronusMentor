class AddDefaultViewToReportSectionsAndReportMetrics< ActiveRecord::Migration[4.2]
  def change
    add_column :report_sections, :default_section, :integer
    add_column :report_metrics, :default_metric, :integer
  end
end
