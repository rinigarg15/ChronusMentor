class AddProfileQuestionIndexToProfileAnswers< ActiveRecord::Migration[4.2]
  def up
    add_index :profile_answers, :profile_question_id
  end

  def down
    remove_index :profile_answers, :profile_question_id
  end
end