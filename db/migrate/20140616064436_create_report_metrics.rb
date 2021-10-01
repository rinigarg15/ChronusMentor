class CreateReportMetrics< ActiveRecord::Migration[4.2]
  def change
    create_table :report_metrics do |t|
      t.string :title
      t.text :description
      t.belongs_to :section
      t.belongs_to :abstract_view

      t.timestamps null: false
    end
    add_index :report_metrics, :section_id
    add_index :report_metrics, :abstract_view_id
  end
end
