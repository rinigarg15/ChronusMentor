require_relative './../../test_helper.rb'

class ThreeSixty::SurveyAssesseeCompetencyInfoTest < ActiveSupport::TestCase
  def test_belongs_to_survey_assessee
    assert_equal three_sixty_survey_assessees(:three_sixty_survey_assessees_1), ThreeSixty::SurveyAssesseeCompetencyInfo.first.survey_assessee
  end

  def test_belongs_to_competency
    assert_equal three_sixty_questions(:listening_1).competency, ThreeSixty::SurveyAssesseeCompetencyInfo.first.competency
  end

  def test_belongs_to_reviewer_group
    assert_equal three_sixty_reviewer_groups(:three_sixty_reviewer_groups_1), three_sixty_survey_assessee_competency_infos(:three_sixty_survey_assessee_competency_infos_2).reviewer_group
    assert_nil three_sixty_survey_assessee_competency_infos(:three_sixty_survey_assessee_competency_infos_1).reviewer_group
  end

  def test_related_competency_infos
    competency_info = ThreeSixty::SurveyAssesseeCompetencyInfo.first
    competency = competency_info.competency
    competency_info.related_competency_infos.each do |ci|
      assert_equal competency, ci.competency
    end
    related_ci = ThreeSixty::SurveyAssesseeCompetencyInfo.create(:survey_assessee => three_sixty_survey_assessees(:three_sixty_survey_assessees_9), :competency => competency, :reviewer_group => three_sixty_reviewer_groups(:three_sixty_reviewer_groups_3))
    unrelated_ci = ThreeSixty::SurveyAssesseeCompetencyInfo.create(:survey_assessee => three_sixty_survey_assessees(:three_sixty_survey_assessees_1), :competency => three_sixty_questions(:delegating_1).competency, :reviewer_group => three_sixty_reviewer_groups(:three_sixty_reviewer_groups_2))
    assert_false unrelated_ci.competency == competency
    assert competency_info.reload.related_competency_infos.include?(related_ci)
    assert_false competency_info.reload.related_competency_infos.include?(unrelated_ci)
  end

  def test_presence_of_survey_assessee
    competency_info = ThreeSixty::SurveyAssesseeCompetencyInfo.new(:competency => three_sixty_questions(:listening_1).competency, :average_value => 0.0, :answer_count => 0)
    competency_info.save
    assert_equal ["can't be blank"], competency_info.errors[:three_sixty_survey_assessee_id]
  end

  def test_presence_of_competency
    competency_info = ThreeSixty::SurveyAssesseeCompetencyInfo.new(:survey_assessee => three_sixty_survey_assessees(:three_sixty_survey_assessees_1), :average_value => 0.0, :answer_count => 0)
    competency_info.save
    assert_equal ["can't be blank"], competency_info.errors[:three_sixty_competency_id]
  end

  def test_uniqueness_of_competency
    competency_info_1 = ThreeSixty::SurveyAssesseeCompetencyInfo.new(:competency => three_sixty_questions(:listening_1).competency, :survey_assessee => three_sixty_survey_assessees(:three_sixty_survey_assessees_1), :average_value => 1.0, :answer_count => 1, :reviewer_group => ThreeSixty::ReviewerGroup.last)
    competency_info_1.save
    assert competency_info_1.valid?

    competency_info_2 = ThreeSixty::SurveyAssesseeCompetencyInfo.new(:competency => three_sixty_questions(:listening_1).competency, :survey_assessee => three_sixty_survey_assessees(:three_sixty_survey_assessees_1), :average_value => 2.0, :answer_count => 2, :reviewer_group => ThreeSixty::ReviewerGroup.last)
    competency_info_2.save
    assert_equal ["has already been taken"], competency_info_2.errors[:three_sixty_competency_id]
  end

  def test_presence_of_average_value
    competency_info = ThreeSixty::SurveyAssesseeCompetencyInfo.new(:competency => three_sixty_questions(:listening_1).competency, :survey_assessee => three_sixty_survey_assessees(:three_sixty_survey_assessees_2), :average_value => nil, :answer_count => 0)
    competency_info.save
    assert_equal ["can't be blank"], competency_info.errors[:average_value]
  end

  def test_presence_of_answer_count
    competency_info = ThreeSixty::SurveyAssesseeCompetencyInfo.new(:competency => three_sixty_questions(:listening_1).competency, :survey_assessee => three_sixty_survey_assessees(:three_sixty_survey_assessees_2), :average_value => 0.0, :answer_count => nil)
    competency_info.save
    assert_equal ["can't be blank"], competency_info.errors[:answer_count]
  end
end