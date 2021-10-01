class AddGoalTypeDeatilsToMentoringModelAndMentoringModelGoalTemplate< ActiveRecord::Migration[4.2]
  def change
    add_column :mentoring_models, :goal_progress_type, :integer, default: MentoringModel::GoalProgressType::AUTO
    add_column :mentoring_model_goal_templates, :program_goal_template_id, :integer
    add_index :mentoring_model_goal_templates, :program_goal_template_id
  end
end
