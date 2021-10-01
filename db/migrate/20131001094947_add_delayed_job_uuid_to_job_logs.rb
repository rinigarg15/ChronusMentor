class AddDelayedJobUuidToJobLogs< ActiveRecord::Migration[4.2]
  def change
    add_column :job_logs, :job_uuid, :string, limit: UTF8MB4_VARCHAR_LIMIT
    add_index :job_logs, :job_uuid
  end
end
