class AddCompletedDateToMentoringModelTasks< ActiveRecord::Migration[4.2]
  def change
    add_column :mentoring_model_tasks, :completed_date, :date
  end
end