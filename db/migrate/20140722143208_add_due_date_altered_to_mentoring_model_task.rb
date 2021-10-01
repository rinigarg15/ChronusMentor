class AddDueDateAlteredToMentoringModelTask< ActiveRecord::Migration[4.2]
  def change
    add_column :mentoring_model_tasks, :due_date_altered, :boolean
  end
end
