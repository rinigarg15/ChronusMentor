class SurveyQuestionObserver < ActiveRecord::Observer

  def after_create(survey_question)
    survey_question.create_survey_response_column
  end

  def after_save(survey_question)
    if survey_question.saved_change_to_survey_id?
      survey_question.survey_answers.update_all("survey_id=#{survey_question.survey_id}")
    end
  end
end
