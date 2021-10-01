class RemoveMatrixSubQuestionsFromSurveyResponseColumn< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      columns_with_matrix_sub_questions = SurveyResponseColumn.joins(:survey_question).where.not(common_questions: { matrix_question_id: nil })
      columns_with_matrix_sub_questions.delete_all
    end
  end

  def down
    # Do nothing
  end
end
