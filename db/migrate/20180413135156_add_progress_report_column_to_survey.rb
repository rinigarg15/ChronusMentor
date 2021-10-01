class AddProgressReportColumnToSurvey < ActiveRecord::Migration[4.2]
	def up
	  ChronusMigrate.ddl_migration do
	    Lhm.change_table :surveys do |t|
	      t.add_column :progress_report, "tinyint(1) DEFAULT false"
	    end
	  end
	end

	def down
	  ChronusMigrate.ddl_migration do
	    Lhm.change_table :surveys do |t|
	    	t.remove_column :progress_report
	    end
	  end
	end
end
