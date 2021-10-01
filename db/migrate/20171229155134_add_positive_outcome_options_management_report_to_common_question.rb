class AddPositiveOutcomeOptionsManagementReportToCommonQuestion< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration do
      Lhm.change_table CommonQuestion.table_name do |t|
        t.add_column :positive_outcome_options_management_report, "text"
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table CommonQuestion.table_name do |t|
        t.remove_column :positive_outcome_options_management_report
      end
    end
  end
end
