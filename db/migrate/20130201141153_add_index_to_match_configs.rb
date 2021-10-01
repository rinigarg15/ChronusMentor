class AddIndexToMatchConfigs< ActiveRecord::Migration[4.2]
  def change
    add_index :match_configs, [:student_question_id]
    add_index :match_configs, [:mentor_question_id]
  end
end
