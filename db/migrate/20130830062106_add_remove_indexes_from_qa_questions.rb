class AddRemoveIndexesFromQaQuestions< ActiveRecord::Migration[4.2]
  def up
    remove_index :qa_questions, [:program_id, :updated_at]
    add_index :qa_questions, :updated_at
    add_index :qa_questions, :user_id
    add_index :qa_questions, :program_id
  end

  def down
    remove_index :qa_questions, :program_id
    remove_index :qa_questions, :user_id
    remove_index :qa_questions, :updated_at
    add_index :qa_questions, [:program_id, :updated_at]
  end
end
