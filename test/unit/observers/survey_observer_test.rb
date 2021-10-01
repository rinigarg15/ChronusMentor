require_relative './../../test_helper.rb'

class SurveyObserverTest < ActiveSupport::TestCase

  def test_before_save
    assert_equal Survey::EditMode::MULTIRESPONSE, create_program_survey.edit_mode
    assert_equal Survey::EditMode::OVERWRITE, create_engagement_survey.edit_mode
    assert_equal Survey::EditMode::OVERWRITE, create_survey({:type => "MeetingFeedbackSurvey", role_name: RoleConstants::MENTOR_NAME}).edit_mode
  end

  def test_after_create
    assert_difference "SurveyResponseColumn.count", 4 do
      assert_difference "CampaignManagement::SurveyCampaign.count", 1 do
        assert_difference "CampaignManagement::SurveyCampaignMessage.count", 2 do
          assert_difference "Mailer::Template.count", 2 do
            create_engagement_survey(:name => "Test Survey", :program => programs(:albers))
          end
        end
      end
    end
  end
end