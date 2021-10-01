class CreateReportViewColumns< ActiveRecord::Migration[4.2]
  def change
    create_table :report_view_columns do |t|
      t.belongs_to :program
      t.string :report_type, limit: UTF8MB4_VARCHAR_LIMIT
      t.text :column_key
      t.integer :position
      t.timestamps null: false
    end
  end
end
