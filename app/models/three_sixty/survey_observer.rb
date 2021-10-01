class ThreeSixty::SurveyObserver < ActiveRecord::Observer
  def after_create(survey)
    survey.create_default_reviewer_group
  end

  def after_save(survey)
    # Elasticsearch delta indexing should happen in es_reindex method so that indexing for update_column/update_all or delete/delete_all will be taken care.
    if survey.saved_change_to_title? || survey.saved_change_to_state? || survey.saved_change_to_expiry_date? || survey.saved_change_to_issue_date?
      ThreeSixty::Survey.es_reindex(survey)
    end
  end

end