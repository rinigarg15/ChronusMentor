class AddIndexForActivityLogs< ActiveRecord::Migration[4.2]
  def up
    add_index :activity_logs, :user_id
  end

  def down
    remove_index :activity_logs, :user_id
  end
end