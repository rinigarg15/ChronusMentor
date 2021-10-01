class AddTaskFilterUserInfoToConnectionMembership< ActiveRecord::Migration[4.2]
  def change
    add_column :connection_memberships, :last_applied_task_filter_user_info, :string
  end
end
