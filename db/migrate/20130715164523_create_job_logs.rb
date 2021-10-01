class CreateJobLogs< ActiveRecord::Migration[4.2]
  def change
    create_table :job_logs do |t|
      t.belongs_to :user
      t.integer :loggable_object_id
      t.string :loggable_object_type, limit: UTF8MB4_VARCHAR_LIMIT
      t.integer :action_type
      t.integer :version_id
      t.timestamps null: false
    end
    add_index :job_logs, [:loggable_object_type, :loggable_object_id]
    add_index :job_logs, :user_id
  end
end