require_relative './../../../test_helper.rb'

class ThreeSixty::AddReviewerPolicyTest < ActiveSupport::TestCase

  def test_admin_managing_survey
    survey_assessee = three_sixty_survey_assessees(:three_sixty_survey_assessees_2)
    survey = survey_assessee.survey
    arp1 = ThreeSixty::AddReviewerPolicy.new(survey_assessee, members(:f_admin), nil)
    assert_false arp1.admin_managing_survey?

    survey.update_attribute(:reviewers_addition_type, ThreeSixty::Survey::ReviewersAdditionType::ADMIN_ONLY)
    arp1 = ThreeSixty::AddReviewerPolicy.new(survey_assessee, members(:f_admin), nil)
    assert arp1.admin_managing_survey?

    arp2 = ThreeSixty::AddReviewerPolicy.new(survey_assessee, members(:ram), nil)
    assert_false arp2.admin_managing_survey?

    arp3 = ThreeSixty::AddReviewerPolicy.new(survey_assessee, members(:ram), users(:ram))
    assert arp3.admin_managing_survey?

    survey.update_attribute(:program_id, nil)
    arp4 = ThreeSixty::AddReviewerPolicy.new(survey_assessee.reload, members(:ram), users(:ram))
    assert_false arp4.admin_managing_survey?
  end

  def test_can_add_reviewers
    survey_assessee = three_sixty_survey_assessees(:three_sixty_survey_assessees_2)
    survey = survey_assessee.survey
    survey.update_attribute(:reviewers_addition_type, ThreeSixty::Survey::ReviewersAdditionType::ADMIN_ONLY)
    arp1 = ThreeSixty::AddReviewerPolicy.new(survey_assessee, members(:f_admin), nil)
    assert arp1.admin_managing_survey?
    assert arp1.can_add_reviewers?

    survey.update_attribute(:reviewers_addition_type, ThreeSixty::Survey::ReviewersAdditionType::ASSESSEE_ONLY)
    arp2 = ThreeSixty::AddReviewerPolicy.new(survey_assessee, members(:f_mentor), nil)
    assert_false arp2.admin_managing_survey?
    assert_false survey_assessee.is_for?(members(:f_mentor))
    assert_false arp2.can_add_reviewers?

    arp3 = ThreeSixty::AddReviewerPolicy.new(survey_assessee, members(:f_student), nil)
    assert_false arp3.admin_managing_survey?
    assert survey_assessee.is_for?(members(:f_student))
    assert arp3.can_add_reviewers?
  end

  def test_can_update_reviewer
    survey_assessee = three_sixty_survey_assessees(:three_sixty_survey_assessees_2)
    survey = survey_assessee.survey
    survey.update_attribute(:reviewers_addition_type, ThreeSixty::Survey::ReviewersAdditionType::ADMIN_ONLY)
    arp1 = ThreeSixty::AddReviewerPolicy.new(survey_assessee, members(:f_admin), nil)
    assert arp1.admin_managing_survey?
    assert arp1.can_add_reviewers?

    survey.update_attribute(:reviewers_addition_type, ThreeSixty::Survey::ReviewersAdditionType::ASSESSEE_ONLY)
    arp2 = ThreeSixty::AddReviewerPolicy.new(survey_assessee, members(:f_mentor), nil)
    assert_false arp2.admin_managing_survey?
    assert_false survey_assessee.is_for?(members(:f_mentor))
    assert_false arp2.can_add_reviewers?

    arp3 = ThreeSixty::AddReviewerPolicy.new(survey_assessee, members(:f_student), nil)
    assert_false arp3.admin_managing_survey?
    assert survey_assessee.is_for?(members(:f_student))
    assert arp3.can_add_reviewers?
  end
end