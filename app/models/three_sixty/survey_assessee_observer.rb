class ThreeSixty::SurveyAssesseeObserver < ActiveRecord::Observer
  def after_create(survey_assessee)
    survey_assessee.create_self_reviewer!
  end
end