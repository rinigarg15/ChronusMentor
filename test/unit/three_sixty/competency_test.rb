require_relative './../../test_helper.rb'

class ThreeSixty::CompetencyTest < ActiveSupport::TestCase
  def test_belongs_to_organization
    assert_equal programs(:org_primary), three_sixty_competencies(:leadership).organization
  end

  def test_has_many_questions
    assert_equal 3, three_sixty_competencies(:leadership).questions.size
    assert_difference "ThreeSixty::Question.count", -3 do
      three_sixty_competencies(:leadership).destroy
    end
  end

  def test_has_many_survey_competencies
    assert_equal 4, three_sixty_competencies(:leadership).survey_competencies.size
    assert_difference "ThreeSixty::SurveyCompetency.count", -4 do
      three_sixty_competencies(:leadership).destroy
    end
  end

  def test_presence_of_organization
    competency = ThreeSixty::Competency.new(:title => 'Some Text')
    competency.save
    assert_equal ["can't be blank"], competency.errors[:organization_id] 
  end

  def test_presence_of_title
    competency = programs(:org_primary).three_sixty_competencies.new
    competency.save
    assert_equal ["can't be blank"], competency.errors[:title]
  end

  def test_uniqueness_of_title_wrt_org
    competency_1 = programs(:org_primary).three_sixty_competencies.new(:title => 'Leadership')
    competency_1.save
    assert_equal ["has to be unique"], competency_1.errors[:title]
    programs(:org_anna_univ).three_sixty_competencies.destroy_all #default competencies has Leadership
    competency_2 = programs(:org_anna_univ).three_sixty_competencies.new(:title => 'Leadership')
    competency_2.save
    assert competency_2.valid?
  end

  def test_scope_with_questions
    comp = three_sixty_competencies(:leadership)
    three_sixty_competencies = programs(:org_primary).three_sixty_competencies.with_questions
    assert three_sixty_competencies.include?(comp)
    assert_false three_sixty_competencies.include?(three_sixty_competencies(:decision_making))
    assert_equal 4, three_sixty_competencies.size

    comp.questions.destroy_all
    three_sixty_competencies = programs(:org_primary).three_sixty_competencies.with_questions
    assert_false three_sixty_competencies.include?(comp)
    assert_equal 3, three_sixty_competencies.size
  end

  def test_translated_fields
    competency = programs(:org_primary).three_sixty_competencies.new(:title => 'globalized competency')
    competency.save!
    Globalize.with_locale(:en) do
      competency.title = "english title"
      competency.description = "english description"
      competency.save!
    end
    Globalize.with_locale(:"fr-CA") do
      competency.title = "french title"
      competency.description = "french description"
      competency.save!
    end
    Globalize.with_locale(:en) do
      assert_equal "english title", competency.title
      assert_equal "english description", competency.description
    end
    Globalize.with_locale(:"fr-CA") do
      assert_equal "french title", competency.title
      assert_equal "french description", competency.description
    end
  end
end