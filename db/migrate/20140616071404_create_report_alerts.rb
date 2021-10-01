class CreateReportAlerts< ActiveRecord::Migration[4.2]
  def change
    create_table :report_alerts do |t|
      t.text :description
      t.text :filter_params
      t.integer :operator
      t.integer :target
      t.belongs_to :metric

      t.timestamps null: false
    end
    add_index :report_alerts, :metric_id
  end
end
