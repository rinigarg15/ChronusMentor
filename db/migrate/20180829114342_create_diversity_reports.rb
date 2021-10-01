class CreateDiversityReports < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.ddl_migration do
      create_table :diversity_reports do |t|
        t.belongs_to :organization
        t.belongs_to :admin_view
        t.belongs_to :profile_question
        t.integer :comparison_type
        t.string :name
        t.timestamps
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      drop_table :diversity_reports
    end
  end
end
