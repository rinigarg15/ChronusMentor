module User::DraftedSurveyResponsesWidget
  extend ActiveSupport::Concern

  def show_drafted_surveys_widget?
    drafted_answers_of_accessible_program_surveys.present? || drafted_answers_of_accessible_engagement_surveys.present?
  end

  def drafted_responses_for_widget
    prog_survey_responses = drafted_answers_of_accessible_program_surveys.select([:survey_id, :response_id, :group_id, :task_id, :last_answered_at]).group(:response_id)
    engagement_survey_responses = drafted_answers_of_accessible_engagement_surveys.select([:survey_id, :response_id, :group_id, :task_id, :last_answered_at]).group(:response_id)

    return (prog_survey_responses + engagement_survey_responses).sort_by(&:last_answered_at)
  end

  def drafted_survey_answers
    self.survey_answers.drafted
  end

  def available_program_surveys
    ProgramSurvey.where(program_id: self.program_id).not_expired.for_role(self.role_names)
  end

  private

  def drafted_answers_of_accessible_program_surveys
    self.drafted_survey_answers.where(survey_id: self.available_program_surveys.pluck(:id))
  end

  def drafted_answers_of_accessible_engagement_surveys
    self.drafted_survey_answers.where(group_id: self.active_groups.pluck(:id), task_id: (self.mentoring_model_tasks.pluck(:id) << nil))
  end
end