require_relative './../../../../../../test_helper'

class ThreeSixtySurveyReviewerPopulatorTest < ActiveSupport::TestCase
  def test_add_three_sixty_survey_reviewers
    program = programs(:albers)
    three_sixty_survey = ThreeSixty::Survey.first
    to_add_three_sixty_survey_assessee_ids = three_sixty_survey.assessees.pluck(:id)
    to_remove_three_sixty_survey_assessee_ids = ThreeSixty::SurveyReviewer.pluck(:three_sixty_survey_assessee_id).uniq.last(5)
    populator_add_and_remove_objects("three_sixty_survey_reviewer", "three_sixty_survey_assessee", to_add_three_sixty_survey_assessee_ids, to_remove_three_sixty_survey_assessee_ids, {program: program, three_sixty_survey: three_sixty_survey, model: "three_sixty/survey_reviewer"})
  end
end