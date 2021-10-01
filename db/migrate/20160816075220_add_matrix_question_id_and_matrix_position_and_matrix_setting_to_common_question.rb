class AddMatrixQuestionIdAndMatrixPositionAndMatrixSettingToCommonQuestion< ActiveRecord::Migration[4.2]
  def change
    add_column :common_questions, :matrix_position, :integer
    add_column :common_questions, :matrix_setting, :integer
    add_column :common_questions, :matrix_question_id, :integer

    add_index :common_questions, :matrix_question_id
  end
end
