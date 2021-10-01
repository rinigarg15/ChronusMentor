class AddConditionToCommonQuestions< ActiveRecord::Migration[4.2]
  def change
    add_column :common_questions, :condition, :integer, default: SurveyQuestion::Condition::ALWAYS
  end
end
