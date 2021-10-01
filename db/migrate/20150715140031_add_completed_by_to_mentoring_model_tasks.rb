class AddCompletedByToMentoringModelTasks< ActiveRecord::Migration[4.2]
  def up
    add_column :mentoring_model_tasks, :completed_by, :integer, default: nil
  end

  def down
    remove_column :mentoring_model_tasks, :completed_by, :integer
  end
end