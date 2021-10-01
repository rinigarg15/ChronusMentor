class AddIndexGroupIdStatusOnMentoringModelTasks< ActiveRecord::Migration[4.2]
  def up
    remove_index :mentoring_model_tasks, [:group_id]
    add_index :mentoring_model_tasks, [:group_id, :status]
  end

  def down
    remove_index :mentoring_model_tasks, [:group_id, :status]
    add_index :mentoring_model_tasks, [:group_id]
  end
end