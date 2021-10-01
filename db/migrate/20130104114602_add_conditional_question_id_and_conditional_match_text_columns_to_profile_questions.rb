class AddConditionalQuestionIdAndConditionalMatchTextColumnsToProfileQuestions< ActiveRecord::Migration[4.2]
  def change
    add_column :profile_questions, :conditional_question_id, :integer
    add_column :profile_questions, :conditional_match_text, :string
  end
end
