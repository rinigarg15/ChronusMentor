class AddIndexOnActionItemMentoringModelTask< ActiveRecord::Migration[4.2]
  def change
    add_index :mentoring_model_tasks, [:action_item_type, :action_item_id], :name => "index_mentoring_model_tasks_on_action_item"
    add_index :mentoring_model_task_templates, [:action_item_type, :action_item_id], :name => "index_mentoring_model_task_templates_on_action_item"
  end
end