require_relative './../../test_helper.rb'

class ThreeSixty::SurveyQuestionTest < ActiveSupport::TestCase
  def test_belongs_to_survey
    assert_equal three_sixty_surveys(:survey_1), three_sixty_survey_questions(:three_sixty_survey_questions_1).survey
  end

  def test_belongs_to_survey_competency
    assert_equal three_sixty_survey_competencies(:three_sixty_survey_competencies_1), three_sixty_survey_questions(:three_sixty_survey_questions_1).survey_competency
  end

  def test_belongs_to_question
    assert_equal three_sixty_questions(:listening_1), three_sixty_survey_questions(:three_sixty_survey_questions_1).question
  end

  def test_has_many_answers
    assert_equal 5, three_sixty_survey_questions(:three_sixty_survey_questions_1).answers.size
    assert_difference "ThreeSixty::SurveyAnswer.count", -5 do
      three_sixty_survey_questions(:three_sixty_survey_questions_1).destroy
    end
  end

  def test_presence_of_survey
    survey_competency = three_sixty_surveys(:survey_1).survey_competencies.create(:competency => three_sixty_competencies(:leadership))
    sq = ThreeSixty::SurveyQuestion.new(:question => three_sixty_questions(:leadership_1), :survey_competency => survey_competency)
    sq.save
    assert_equal ["can't be blank"], sq.errors[:three_sixty_survey_id]
  end

  def test_presence_of_survey_competency
    sq1 = ThreeSixty::SurveyQuestion.new(:question => three_sixty_questions(:listening_1), :survey => three_sixty_surveys(:survey_1))
    sq1.save
    assert_equal ["can't be blank"], sq1.errors[:three_sixty_survey_competency_id]

    sq2 = ThreeSixty::SurveyQuestion.new(:question => three_sixty_questions(:oeq_3), :survey => three_sixty_surveys(:survey_1))
    sq2.save
    assert sq2.valid?
  end

  def test_presence_of_question
    sq = three_sixty_survey_competencies(:three_sixty_survey_competencies_1).survey_questions.new(:survey => three_sixty_surveys(:survey_1))
    assert_raise NoMethodError do
      sq.save
    end
  end

  def test_uniqueness_of_question
    sq1 = three_sixty_survey_competencies(:three_sixty_survey_competencies_1).survey_questions.create(:question => three_sixty_questions(:listening_1), :survey => three_sixty_surveys(:survey_1))
    assert_equal ["has already been taken"], sq1.errors[:three_sixty_question_id]

    sq2 = three_sixty_surveys(:survey_1).survey_questions.create(:question => three_sixty_questions(:oeq_3))
    assert_equal [], sq2.errors[:three_sixty_question_id]

    sq3 = three_sixty_surveys(:survey_1).survey_questions.create(:question => three_sixty_questions(:oeq_3))
    assert_equal ["has already been taken"], sq3.errors[:three_sixty_question_id]
  end

  def test_position
    ThreeSixty::SurveyQuestion.destroy_all
    sc = three_sixty_competencies(:leadership).survey_competencies.create!(:survey => three_sixty_surveys(:survey_1))

    sq_1 = sc.survey_questions.new(:question => three_sixty_questions(:leadership_1), :survey => three_sixty_surveys(:survey_1))
    assert_nil sq_1.position
    sq_1.save!
    assert_equal 1, sq_1.position

    sq_1.position = 2
    sq_1.save!

    sq_2 = sc.survey_questions.new(:question => three_sixty_questions(:leadership_2), :survey => three_sixty_surveys(:survey_1))
    sq_2.save!
    assert_equal 3, sq_2.position

    sq_2.position = 2
    sq_2.save
    assert_equal ["has already been taken"], sq_2.errors[:position]
  end

  def test_survey_competency_belongs_to_survey
    assert_false three_sixty_survey_competencies(:three_sixty_survey_competencies_1).survey == three_sixty_surveys(:survey_2)
    sq = three_sixty_survey_competencies(:three_sixty_survey_competencies_1).survey_questions.new(:question => three_sixty_questions(:leadership_1), :survey => three_sixty_surveys(:survey_2))
    sq.save
    assert_equal ["survey competency should belong to the same survey"], sq.errors[:three_sixty_survey_competency_id]
  end

  def test_survey_competency_and_question_belong_to_same_competency
    assert_false three_sixty_survey_competencies(:three_sixty_survey_competencies_1).competency == three_sixty_questions(:leadership_1).competency
    sq = three_sixty_survey_competencies(:three_sixty_survey_competencies_1).survey_questions.new(:question => three_sixty_questions(:leadership_1), :survey => three_sixty_surveys(:survey_1))
    sq.save
    assert_equal ["question should belong to the same competency"], sq.errors[:three_sixty_question_id]
  end

  def test_destroy_survey_competency_if_no_questions
    assert_equal 1, three_sixty_survey_competencies(:three_sixty_survey_competencies_1).survey_questions.size
    assert_equal 3, three_sixty_survey_competencies(:three_sixty_survey_competencies_6).survey_questions.size
    
    assert_difference "ThreeSixty::SurveyCompetency.count", -1 do
      assert_difference "ThreeSixty::SurveyQuestion.count", -1 do
        three_sixty_survey_competencies(:three_sixty_survey_competencies_1).survey_questions.first.destroy
      end
    end

    assert_no_difference "ThreeSixty::SurveyCompetency.count" do
      assert_difference "ThreeSixty::SurveyQuestion.count", -1 do
        three_sixty_survey_competencies(:three_sixty_survey_competencies_6).survey_questions.first.destroy
      end
    end
  end
end