class SurveyAnswerObserver < ActiveRecord::Observer
  def before_save(survey_answer)
    survey = survey_answer.survey_question.survey
    survey_answer.survey_id = survey.id
    if survey.engagement_survey? && survey_answer.task.present?
      survey_answer.group_id = survey_answer.task.group_id
      connection_membership = survey_answer.group.membership_of(survey_answer.user)
      survey_answer.connection_membership_role_id = connection_membership.role_id if connection_membership.present?
    end
    survey_answer.last_answered_at ||= Time.now.utc
  end

  def after_save(survey_answer)
    reindex_followups(survey_answer)
  end

  def after_destroy(survey_answer)
    Survey.delay.update_total_responses_for_survey!(survey_answer.survey_id)
    reindex_followups(survey_answer)
  end

  private

  def reindex_followups(survey_answer)
    SurveyAnswer.es_reindex(survey_answer)
  end
end
