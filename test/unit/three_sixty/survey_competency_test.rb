require_relative './../../test_helper.rb'

class ThreeSixty::SurveyCompetencyTest < ActiveSupport::TestCase
  def test_belongs_to_survey
    assert_equal three_sixty_surveys(:survey_1), three_sixty_survey_competencies(:three_sixty_survey_competencies_1).survey
  end

  def test_belongs_to_competency
    assert_equal three_sixty_competencies(:listening), three_sixty_survey_competencies(:three_sixty_survey_competencies_1).competency
  end

  def test_has_many_survey_questions
    assert_equal 1, three_sixty_survey_competencies(:three_sixty_survey_competencies_1).survey_questions.size
    assert_difference "ThreeSixty::SurveyQuestion.count", -1 do
      three_sixty_survey_competencies(:three_sixty_survey_competencies_1).destroy
    end
  end

  def test_has_many_questions
    assert_equal 1, three_sixty_survey_competencies(:three_sixty_survey_competencies_1).questions.size
    assert_no_difference "ThreeSixty::Question.count" do
      three_sixty_survey_competencies(:three_sixty_survey_competencies_1).destroy
    end
  end

  def test_presence_of_survey
    sc = ThreeSixty::SurveyCompetency.new(:competency => three_sixty_competencies(:listening))
    assert_raise NoMethodError do
      sc.save
    end
  end

  def test_presence_of_competency
    sc = three_sixty_surveys(:survey_1).survey_competencies.new
    assert_raise NoMethodError do
      sc.save
    end
  end

  def test_uniqueness_of_competency
    sc = three_sixty_surveys(:survey_1).survey_competencies.create(:competency => three_sixty_competencies(:listening))
    assert_equal ["has already been taken"], sc.errors[:three_sixty_competency_id]
  end

  def test_position
    ThreeSixty::SurveyCompetency.destroy_all

    sc_1 = three_sixty_competencies(:leadership).survey_competencies.new(:survey => three_sixty_surveys(:survey_1))
    assert_nil sc_1.position
    sc_1.save!
    assert_equal 1, sc_1.position

    sc_1.position = 2
    sc_1.save!

    sc_2 = three_sixty_competencies(:decision_making).survey_competencies.new(:survey => three_sixty_surveys(:survey_1))
    sc_2.save!
    assert_equal 3, sc_2.position

    sc_2.position = 2
    sc_2.save
    assert_equal ["has already been taken"], sc_2.errors[:position]
  end

  def test_survey_and_competency_belong_to_same_organization
    survey = programs(:org_anna_univ).three_sixty_surveys.create!(:title => "Diffetent org survey")
    assert_false three_sixty_competencies(:listening).organization == survey.organization
    sc = three_sixty_competencies(:listening).survey_competencies.new(:survey => survey)
    sc.save
    assert_equal ["competency should belong to the same organization as the survey"], sc.errors[:three_sixty_competency_id]
  end

  def test_title
    assert_equal three_sixty_survey_competencies(:three_sixty_survey_competencies_1).competency.title, three_sixty_survey_competencies(:three_sixty_survey_competencies_1).title
  end

  def test_add_questions
    sc = three_sixty_competencies(:leadership).survey_competencies.new(:survey => three_sixty_surveys(:survey_1))
    sc.save!

    assert_equal 0, sc.survey_questions.count
    q_ids = [three_sixty_questions(:leadership_1).id, three_sixty_questions(:leadership_2).id]

    assert_difference "ThreeSixty::SurveyQuestion.count", 2 do
      sc.add_questions(q_ids)
    end

    q_ids = [three_sixty_questions(:leadership_1).id, three_sixty_questions(:leadership_2).id, three_sixty_questions(:leadership_3).id]
    assert_difference "ThreeSixty::SurveyQuestion.count", 1 do
      sc.add_questions(q_ids)
    end
  end
end