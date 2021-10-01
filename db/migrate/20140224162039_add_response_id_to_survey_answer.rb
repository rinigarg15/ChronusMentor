class AddResponseIdToSurveyAnswer< ActiveRecord::Migration[4.2]
  def change
    add_column :common_answers, :response_id, :integer
    add_index :common_answers, [:type, :response_id]
    remove_index :common_answers, [:type, :survey_id]
    add_index :common_answers, [:survey_id, :type]

    add_index :common_questions, [:survey_id, :type]

    SurveyAnswer.reset_column_information
    Survey.unscoped.find_each do |survey|
      user_ids = survey.survey_answers.pluck(:user_id)
      user_ids.each_with_index do |user_id, index|
        survey.survey_answers.where(user_id: user_id).update_all(:response_id => index+1)
      end
    end
  end
end
