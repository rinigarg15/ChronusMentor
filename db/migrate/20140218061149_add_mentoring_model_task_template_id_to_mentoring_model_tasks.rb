class AddMentoringModelTaskTemplateIdToMentoringModelTasks< ActiveRecord::Migration[4.2]
  def change
    add_column :mentoring_model_tasks, :mentoring_model_task_template_id, :integer
    add_index :mentoring_model_tasks, :mentoring_model_task_template_id
  end
end
