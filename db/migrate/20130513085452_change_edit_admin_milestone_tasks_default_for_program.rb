class ChangeEditAdminMilestoneTasksDefaultForProgram< ActiveRecord::Migration[4.2]
  def change
    change_column :programs, :cannot_edit_admin_task_owner, :boolean, :default => true
  end
end