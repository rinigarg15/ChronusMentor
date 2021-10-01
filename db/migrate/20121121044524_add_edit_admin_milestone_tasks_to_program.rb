class AddEditAdminMilestoneTasksToProgram< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :cannot_edit_admin_task_owner, :boolean, :default => false 
  end
end
