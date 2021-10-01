require_relative './../../../test_helper'

class ThreeSixty::SurveyObserverTest < ActiveSupport::TestCase
  def test_after_create
    assert_difference "ThreeSixty::SurveyReviewerGroup.count", 1 do
      programs(:org_primary).three_sixty_surveys.create!(:title => "For obsetrver Test")
    end
  end

  def test_after_save
    survey = three_sixty_surveys(:survey_1)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(ThreeSixty::SurveyAssessee, survey.survey_assessees.pluck(:id))
    survey.title = "Test"
    survey.save!
  end
end