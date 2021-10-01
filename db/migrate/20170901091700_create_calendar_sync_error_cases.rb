class CreateCalendarSyncErrorCases< ActiveRecord::Migration[4.2]
  def change
  	ChronusMigrate.ddl_migration do
      create_table :calendar_sync_error_cases do |t|
        t.string :scenario, null: false
        t.text :details
        t.timestamps null: false
      end
    end
  end
end
