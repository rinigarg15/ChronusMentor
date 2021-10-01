class CreateMatchReportAdminView < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.ddl_migration do
      create_table :match_report_admin_views do |t|
        t.references :program, index: true
        t.references :admin_view, index: true
        t.string :section_type
        t.string :role_type
        t.timestamps null: false
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      drop_table :match_report_admin_views
    end
  end

end
