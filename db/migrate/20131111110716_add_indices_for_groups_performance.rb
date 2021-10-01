class AddIndicesForGroupsPerformance< ActiveRecord::Migration[4.2]
  def up
  	add_index :tasks, :group_id
  	add_index :connection_milestones, :template_milestone_id
  	add_index :connection_tasks, :owner_id
  end

  def down
  	remove_index :tasks, :group_id
  	remove_index :connection_milestones, :template_milestone_id
  	remove_index :connection_tasks, :owner_id
  end
end
