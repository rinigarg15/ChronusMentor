class AddPositiveOutcomeToCommonQuestions< ActiveRecord::Migration[4.2]
  def change
    add_column :common_questions, :positive_outcome_options, :text, default: nil
  end
end
