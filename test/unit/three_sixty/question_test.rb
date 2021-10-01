require_relative './../../test_helper.rb'

class ThreeSixty::QuestionTest < ActiveSupport::TestCase
  def test_belongs_to_competency
    assert_equal three_sixty_competencies(:leadership), three_sixty_questions(:leadership_1).competency
    assert_nil three_sixty_questions(:oeq_1).competency
  end

  def test_belongs_to_organization
    assert_equal programs(:org_primary), three_sixty_questions(:leadership_1).organization
  end

  def test_has_many_survey_questions
    assert_equal 2, three_sixty_questions(:listening_1).survey_questions.size
    assert_difference "ThreeSixty::SurveyQuestion.count", -2 do
      three_sixty_questions(:listening_1).destroy
    end
  end

  def test_has_many_answers
    assert_equal 5, three_sixty_questions(:listening_1).survey_answers.size
  end

  def test_has_many_survey_assessee_question_infos
    assert_equal 5, three_sixty_questions(:listening_1).survey_assessee_question_infos.size
    assert_difference "ThreeSixty::SurveyAssesseeQuestionInfo.count", -5 do
      three_sixty_questions(:listening_1).destroy
    end
  end

  def test_presence_of_organization
    question = three_sixty_competencies(:leadership).questions.new(:title => 'Some Text', :question_type => 0)
    question.save
    assert_equal ["can't be blank"], question.errors[:organization_id] 
  end

  def test_presence_of_competency_only_for_rating_type_question
    question1 = ThreeSixty::Question.new(:title => 'Some Text', :question_type => ThreeSixty::Question::Type::RATING, :organization => programs(:org_primary))
    question1.save
    assert_equal ["can't be blank"], question1.errors[:three_sixty_competency_id]

    question2 = ThreeSixty::Question.new(:title => 'Some Text', :question_type => ThreeSixty::Question::Type::TEXT, :organization => programs(:org_primary))
    question2.save
    assert question2.valid?
  end

  def test_presence_of_title
    question = three_sixty_competencies(:leadership).questions.new(:question_type => 0, :organization => programs(:org_primary))
    question.save
    assert_equal ["can't be blank"], question.errors[:title]
  end

  def test_uniqueness_of_title_wrt_competency_and_org
    question_1 = three_sixty_competencies(:leadership).questions.new(:title => 'Are you a leader?', :question_type => 0, :organization => programs(:org_primary))
    question_1.save
    assert_equal ["has to be unique"], question_1.errors[:title]

    question_2 = three_sixty_competencies(:delegating).questions.new(:title => 'Are you a leader?', :question_type => 0, :organization => programs(:org_primary))
    question_2.save
    assert question_2.valid?

    question_3 = ThreeSixty::Question.new(:title => 'Are you a leader?', :question_type => 1, :organization => programs(:org_primary))
    question_3.save
    assert question_3.valid?

    question_4 = ThreeSixty::Question.new(:title => 'Are you a leader?', :question_type => 1, :organization => programs(:org_primary))
    question_4.save
    assert_false question_4.valid?

    question_5 = ThreeSixty::Question.new(:title => 'Are you a leader?', :question_type => 1, :organization => programs(:org_anna_univ))
    question_5.save
    assert question_5.valid?
  end

  def test_presence_of_question_type_in_valid_types
    question_1 = three_sixty_competencies(:leadership).questions.new(:title => 'Some text', :organization => programs(:org_primary))
    question_1.save
    assert_equal ["can't be blank", "is not included in the list"], question_1.errors[:question_type]

    question_2 = three_sixty_competencies(:leadership).questions.new(:title => 'Some text', :question_type => 2, :organization => programs(:org_primary))
    question_2.save
    assert_equal ["is not included in the list"], question_2.errors[:question_type]
  end

  def test_competency_belongs_to_organization
    assert_equal programs(:org_primary), three_sixty_competencies(:leadership).organization
    question_1 = three_sixty_competencies(:leadership).questions.new(:title => 'Some title', :question_type => 1, :organization => programs(:org_anna_univ))
    question_1.save
    assert_equal ["competency should belong to the organization"], question_1.errors[:three_sixty_competency_id]
  end

  def test_of_rating_type
    question1 = three_sixty_competencies(:leadership).questions.create(:title => "rating type", :question_type => 0, :organization => programs(:org_primary))
    question2 = three_sixty_competencies(:leadership).questions.create(:title => "text type", :question_type => 1, :organization => programs(:org_primary))
    assert question1.of_rating_type?
    assert_false question2.of_rating_type?
  end

  def test_scope_of_rating_type
    assert_equal three_sixty_competencies(:leadership).questions, three_sixty_competencies(:leadership).questions.of_rating_type
    question1 = three_sixty_competencies(:leadership).questions.create(:title => "rating type", :question_type => 0, :organization => programs(:org_primary))
    question2 = three_sixty_competencies(:leadership).questions.create(:title => "text type", :question_type => 1, :organization => programs(:org_primary))
    assert three_sixty_competencies(:leadership).questions.of_rating_type.include?(question1)
    assert_false three_sixty_competencies(:leadership).questions.of_rating_type.include?(question2)
  end

  def test_scope_of_text_type
    assert_equal [], three_sixty_competencies(:leadership).questions.of_text_type
    question1 = three_sixty_competencies(:leadership).questions.create(:title => "rating type", :question_type => 0, :organization => programs(:org_primary))
    question2 = three_sixty_competencies(:leadership).questions.create(:title => "text type", :question_type => 1, :organization => programs(:org_primary))
    assert_false three_sixty_competencies(:leadership).questions.of_text_type.include?(question1)
    assert three_sixty_competencies(:leadership).questions.of_text_type.include?(question2)
  end

  def test_translated_fields
    question = three_sixty_competencies(:leadership).questions.new(:title => "globalized question", :question_type => 0, :organization => programs(:org_primary))
    question.save!
    Globalize.with_locale(:en) do
      question.title = "english title"
      question.save!
    end
    Globalize.with_locale(:"fr-CA") do
      question.title = "french title"
      question.save!
    end
    Globalize.with_locale(:en) do
      assert_equal "english title", question.title
    end
    Globalize.with_locale(:"fr-CA") do
      assert_equal "french title", question.title
    end
  end
end