require_relative './../../../test_helper.rb'

class ThreeSixty::SurveyPolicyTest < ActiveSupport::TestCase

  def test_not_accessible
    survey = three_sixty_surveys(:survey_1)
    sp_1 = ThreeSixty::SurveyPolicy.new(survey)
    assert_false sp_1.not_accessible?
    assert_nil sp_1.error_message
    
    survey.update_attribute(:expiry_date, 1.day.ago)
    sp_2 = ThreeSixty::SurveyPolicy.new(survey)
    assert sp_2.not_accessible?
    assert_equal "The survey you are looking for has expired.", sp_2.error_message
  end

  def test_not_editable
    survey = three_sixty_surveys(:survey_1)
    assert survey.drafted?
    sp_1 = ThreeSixty::SurveyPolicy.new(survey)
    assert_false sp_1.not_editable?
    assert_nil sp_1.error_message

    survey.publish!
    sp_2 = ThreeSixty::SurveyPolicy.new(survey)
    assert sp_2.not_editable?
    assert_equal "You cannot modify a survey once it is published.", sp_2.error_message
  end

  def test_settings_error
    survey = three_sixty_surveys(:survey_1)
    sp_1 = ThreeSixty::SurveyPolicy.new(survey)
    assert_false sp_1.settings_error?
    assert_nil sp_1.error_message

    survey.update_attribute(:expiry_date, 1.day.ago)
    sp_2 = ThreeSixty::SurveyPolicy.new(survey)
    assert sp_2.settings_error?
    assert_equal "Please select a valid expiration date.", sp_2.error_message

    survey.update_attribute(:expiry_date, 1.day.from_now)
    survey.survey_reviewer_groups.destroy_all
    sp_3 = ThreeSixty::SurveyPolicy.new(survey)
    assert sp_3.settings_error?
    assert_equal "Please select at least one reviewer group.", sp_3.error_message
    
    survey.create_default_reviewer_group
    sp_4 = ThreeSixty::SurveyPolicy.new(survey)
    assert sp_4.settings_error?
    assert_equal "Please select at least one reviewer group.", sp_4.error_message
  end

  def test_questions_error
    survey = three_sixty_surveys(:survey_1)
    sp_1 = ThreeSixty::SurveyPolicy.new(survey)
    assert_false sp_1.questions_error?
    assert_nil sp_1.error_message

    survey.survey_competencies.destroy_all
    survey.survey_oeqs.destroy_all
    sp_2 = ThreeSixty::SurveyPolicy.new(survey)
    assert sp_2.questions_error?
    assert_equal "Please select at least one question before proceeding to preview.", sp_2.error_message
  end
end