require_relative './../../test_helper.rb'

class ThreeSixty::SurveyReviewerGroupTest < ActiveSupport::TestCase
  def test_belongs_to_survey
    assert_equal three_sixty_surveys(:survey_1), three_sixty_survey_reviewer_groups(:three_sixty_survey_reviewer_groups_1).survey
  end

  def test_belongs_to_reviewer_group
    assert_equal three_sixty_reviewer_groups(:three_sixty_reviewer_groups_1), three_sixty_survey_reviewer_groups(:three_sixty_survey_reviewer_groups_1).reviewer_group
  end

  def test_reviewers
    assert_equal 3, three_sixty_survey_reviewer_groups(:three_sixty_survey_reviewer_groups_1).reviewers.size
    assert_difference "ThreeSixty::SurveyReviewer.count", -3 do
      three_sixty_survey_reviewer_groups(:three_sixty_survey_reviewer_groups_1).destroy
    end
  end

  def test_presence_of_reviewer_group
    survey_reviewer_group = ThreeSixty::SurveyReviewerGroup.new(:survey => three_sixty_surveys(:survey_1))
    assert_raise NoMethodError do
      survey_reviewer_group.save
    end
  end

  def test_uniqueness_of_reviewer_group
    survey_reviewer_group = ThreeSixty::SurveyReviewerGroup.new(:survey => three_sixty_surveys(:survey_1), :reviewer_group => three_sixty_reviewer_groups(:three_sixty_reviewer_groups_1))
    survey_reviewer_group.save
    assert_equal ["has already been taken"], survey_reviewer_group.errors[:three_sixty_reviewer_group_id]
  end

  def test_presence_of_survey
    survey_reviewer_group = ThreeSixty::SurveyReviewerGroup.new(:reviewer_group => three_sixty_reviewer_groups(:three_sixty_reviewer_groups_1))
    assert_raise NoMethodError do
      survey_reviewer_group.save
    end
  end

  def test_survey_and_reviewer_group_belong_to_same_organization
    survey_reviewer_group = ThreeSixty::SurveyReviewerGroup.new(:survey => three_sixty_surveys(:survey_1), :reviewer_group => programs(:org_anna_univ).three_sixty_reviewer_groups.first)
    survey_reviewer_group.save
    assert_equal ["reviewer group being selected should belong to the same organization as the survey"], survey_reviewer_group.errors[:three_sixty_reviewer_group_id]
  end

  def test_excluding_self_type
    assert_equal 3, three_sixty_surveys(:survey_1).survey_reviewer_groups.excluding_self_type.count
    assert_false three_sixty_surveys(:survey_1).survey_reviewer_groups.excluding_self_type.include?(three_sixty_survey_reviewer_groups(:three_sixty_survey_reviewer_groups_1))
    three_sixty_survey_reviewer_groups(:three_sixty_survey_reviewer_groups_1).update_attribute(:three_sixty_reviewer_group_id, three_sixty_reviewer_groups(:three_sixty_reviewer_groups_2).id)
    assert_equal 4, three_sixty_surveys(:survey_1).reload.survey_reviewer_groups.excluding_self_type.count
    assert three_sixty_surveys(:survey_1).survey_reviewer_groups.excluding_self_type.include?(three_sixty_survey_reviewer_groups(:three_sixty_survey_reviewer_groups_1))
  end

  def test_name
    assert_equal three_sixty_survey_reviewer_groups(:three_sixty_survey_reviewer_groups_1).reviewer_group.name, three_sixty_survey_reviewer_groups(:three_sixty_survey_reviewer_groups_1).name
  end
end