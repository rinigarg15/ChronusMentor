require_relative './../../../test_helper'

class ThreeSixty::SurveyAssesseeObserverTest < ActiveSupport::TestCase
  def test_after_create
    assert_difference "ThreeSixty::SurveyReviewer.count", 1 do
      three_sixty_surveys(:survey_1).survey_assessees.create!(:assessee => members(:student_0))
    end
  end
end