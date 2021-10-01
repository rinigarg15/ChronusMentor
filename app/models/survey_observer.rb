class SurveyObserver < ActiveRecord::Observer

  def after_create(survey)
    survey.create_default_survey_response_columns
    survey.create_default_campaign unless survey.from_solution_pack
  end

  def before_save(survey)
    # Set default edit_mode
    # Feedback Survey is always set to have multiple responses, irrespective of edit mode
    if survey.form_type_changed?
      survey.edit_mode = survey.is_feedback_survey? ? Survey::EditMode::MULTIRESPONSE : Survey::EditMode::OVERWRITE
    end
    survey.edit_mode ||= Survey::EditMode::MULTIRESPONSE if survey.program_survey? || survey.is_feedback_survey?
    survey.edit_mode ||= Survey::EditMode::OVERWRITE if survey.engagement_survey? || survey.meeting_feedback_survey?
  end
end