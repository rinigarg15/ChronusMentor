class AddMentoringModelTaskIdToSurveyAnswer< ActiveRecord::Migration[4.2]
  def change
    add_column :common_answers, :task_id, :integer
    add_index :common_answers, :task_id
  end
end
