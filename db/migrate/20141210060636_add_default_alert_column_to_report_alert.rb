class AddDefaultAlertColumnToReportAlert< ActiveRecord::Migration[4.2]
  def change
    add_column :report_alerts, :default_alert, :integer
  end
end