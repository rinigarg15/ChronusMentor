class AddQuestionModeToCommonQuestions< ActiveRecord::Migration[4.2]
  def up
    add_column :common_questions, :question_mode, :integer
  end

  def down
    remove_column :common_questions, :question_mode, :integer
  end
end
