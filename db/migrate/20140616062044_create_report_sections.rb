class CreateReportSections< ActiveRecord::Migration[4.2]
  def change
    create_table :report_sections do |t|
      t.string :title
      t.text :description
      t.integer :report_type
      t.belongs_to :program

      t.timestamps null: false
    end
    add_index :report_sections, [:program_id, :report_type]
  end
end
