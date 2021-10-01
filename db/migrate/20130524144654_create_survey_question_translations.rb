class CreateSurveyQuestionTranslations< ActiveRecord::Migration[4.2]
  def up
    SurveyQuestion.create_translation_table!({
      question_text: :text,
      help_text: :text
    }, {
      migrate_data: true
    })
  end

  def down
    SurveyQuestion.drop_translation_table! migrate_data: true
  end
end
