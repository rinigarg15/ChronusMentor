require_relative './../../../../../../test_helper'

class ThreeSixtySurveyAssesseePopulatorTest < ActiveSupport::TestCase
  def test_add_three_sixty_survey_assessees
    program = programs(:albers)
    to_add_member_ids = program.users.pluck(:member_id).first(5)
    to_remove_member_ids = ThreeSixty::SurveyAssessee.pluck(:member_id).uniq.last(5)
    populator_add_and_remove_objects("three_sixty_survey_assessee", "member", to_add_member_ids, to_remove_member_ids, {program: program, model: "three_sixty/survey_assessee"})
  end
end