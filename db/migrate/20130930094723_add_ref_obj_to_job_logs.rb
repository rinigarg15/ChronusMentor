class AddRefObjToJobLogs< ActiveRecord::Migration[4.2]
  def change
    change_table :job_logs do |t|
      t.remove_index :user_id
      t.rename :user_id, :ref_obj_id
      t.column :ref_obj_type, :string, limit: UTF8MB4_VARCHAR_LIMIT
      t.index [:ref_obj_type, :ref_obj_id]
    end
    JobLog.update_all(["ref_obj_type=?", User.name])
  end
end