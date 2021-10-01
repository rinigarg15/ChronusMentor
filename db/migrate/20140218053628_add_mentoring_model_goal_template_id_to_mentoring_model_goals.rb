class AddMentoringModelGoalTemplateIdToMentoringModelGoals< ActiveRecord::Migration[4.2]
  def change
    add_column :mentoring_model_goals, :mentoring_model_goal_template_id, :integer
    add_index :mentoring_model_goals, :mentoring_model_goal_template_id
  end
end
