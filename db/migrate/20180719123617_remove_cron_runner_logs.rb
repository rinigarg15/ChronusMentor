class RemoveCronRunnerLogs < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.ddl_migration do
      drop_table :cron_runner_logs
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      create_table :cron_runner_logs do |t|
        t.string :cron_name, limit: UTF8MB4_VARCHAR_LIMIT
        t.string :status, limit: UTF8MB4_VARCHAR_LIMIT
        t.index :cron_name, unique: true
        t.index :status
        t.timestamps null: false
      end
    end
  end
end