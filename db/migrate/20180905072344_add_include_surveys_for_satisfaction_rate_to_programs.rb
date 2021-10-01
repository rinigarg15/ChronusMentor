class AddIncludeSurveysForSatisfactionRateToPrograms < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table Program.table_name do |table|
        table.add_column :include_surveys_for_satisfaction_rate, :boolean
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table Program.table_name do |table|
        table.remove_column :include_surveys_for_satisfaction_rate
      end
    end
  end
end
