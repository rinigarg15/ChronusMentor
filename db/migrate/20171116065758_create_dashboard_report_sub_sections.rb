class CreateDashboardReportSubSections< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      create_table :dashboard_report_sub_sections do |t|
        t.references :program, index: true
        t.string :report_type
        t.boolean :enabled
        t.string :setting
        t.timestamps null: false
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      drop_table :dashboard_report_sub_sections
    end
  end
end