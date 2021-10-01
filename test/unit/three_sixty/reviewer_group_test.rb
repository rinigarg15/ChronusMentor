require_relative './../../test_helper.rb'

class ThreeSixty::ReviewerGroupTest < ActiveSupport::TestCase
  def test_belongs_to_organization
    assert_equal programs(:org_primary), three_sixty_reviewer_groups(:three_sixty_reviewer_groups_1).organization
  end

  def test_has_many_survey_reviewer_groups
    assert_equal 5, three_sixty_reviewer_groups(:three_sixty_reviewer_groups_1).survey_reviewer_groups.size
    assert_difference "ThreeSixty::SurveyReviewerGroup.count", -5 do
      three_sixty_reviewer_groups(:three_sixty_reviewer_groups_1).destroy
    end
  end

  def test_has_many_survey_assessee_question_infos
    assert_equal 1, three_sixty_reviewer_groups(:three_sixty_reviewer_groups_1).survey_assessee_question_infos.size
    assert_difference "ThreeSixty::SurveyAssesseeQuestionInfo.count", -1 do
      three_sixty_reviewer_groups(:three_sixty_reviewer_groups_1).destroy
    end
  end

  def test_presence_of_organization
    reviewer_group = ThreeSixty::ReviewerGroup.new(:name => 'Some Text', :threshold => 7)
    reviewer_group.save
    assert_equal ["can't be blank"], reviewer_group.errors[:organization_id] 
  end

  def test_presence_of_name
    reviewer_group = programs(:org_primary).three_sixty_reviewer_groups.new(:threshold => 7)
    reviewer_group.save
    assert_equal ["can't be blank"], reviewer_group.errors[:name]
  end

  def test_uniqueness_of_title_wrt_org
    reviewer_group_1 = programs(:org_primary).three_sixty_reviewer_groups.new(:name => 'Text', :threshold => 7)
    reviewer_group_1.save!

    reviewer_group_2 = programs(:org_primary).three_sixty_reviewer_groups.new(:name => 'Text', :threshold => 7)
    reviewer_group_2.save
    assert_equal ["name must be unique"], reviewer_group_2.errors[:name]

    reviewer_group_3 = programs(:org_anna_univ).three_sixty_reviewer_groups.new(:name => 'Text', :threshold => 7)
    reviewer_group_3.save
    assert reviewer_group_3.valid?
  end

  def test_presence_of_threshold
    reviewer_group = programs(:org_primary).three_sixty_reviewer_groups.new(:name => 'new RG')
    reviewer_group.save
    assert_equal ["can't be blank", "is not a number"], reviewer_group.errors[:threshold]
    reviewer_group.threshold = "Random Test"
    reviewer_group.save
    assert_equal ["is not a number"], reviewer_group.errors[:threshold]
    reviewer_group.threshold = -5
    reviewer_group.save
    assert_equal ["must be greater than or equal to 0"], reviewer_group.errors[:threshold]
  end

  def test_scope_excluding_self_type
    reviewer_groups = programs(:org_primary).three_sixty_reviewer_groups.excluding_self_type
    assert_equal 4, reviewer_groups.size

    reviewer_groups.each do |rg|
      assert_false rg.is_for_self?
    end
  end

  def test_scope_of_self_type
    reviewer_groups = programs(:org_primary).three_sixty_reviewer_groups.of_self_type
    assert_equal 1, reviewer_groups.size
    assert reviewer_groups.first.is_for_self?
  end

  def test_create_default_review_groups_for_organization
    programs(:org_primary).three_sixty_reviewer_groups.destroy_all
    assert_difference "ThreeSixty::ReviewerGroup.count", 5 do
      ThreeSixty::ReviewerGroup.create_default_review_groups_for_organization!(programs(:org_primary))
    end
    assert_equal_unordered ThreeSixty::ReviewerGroup::DefaultName.all, programs(:org_primary).three_sixty_reviewer_groups.collect(&:name)
    new_reviewer_groups = programs(:org_primary).three_sixty_reviewer_groups.index_by(&:name)
    ThreeSixty::ReviewerGroup::DefaultName.all.each do |name|
      assert_equal ThreeSixty::ReviewerGroup::DefaultThreshold[name], new_reviewer_groups[name].threshold
    end
  end

  def test_is_for_self
    reviewer_group_1 = programs(:org_primary).three_sixty_reviewer_groups.new(:name => 'Text', :threshold => 7)
    reviewer_group_1.save!

    assert_false reviewer_group_1.is_for_self?
    assert programs(:org_primary).three_sixty_reviewer_groups.find_by(name: ThreeSixty::ReviewerGroup::DefaultName::SELF)
  end

  def test_error_for_display
    assert_nil three_sixty_reviewer_groups(:three_sixty_reviewer_groups_1).error_for_display

    rg = programs(:org_primary).three_sixty_reviewer_groups.create(:name => "Other", :threshold => "sometinng thats not a number")
    assert_equal "Reviewer Group already exists and threshold must be a number greater than or equal to 0.", rg.error_for_display

    rg.update_attributes(:name => "Something new")
    assert_equal "Threshold must be a number greater than or equal to 0.", rg.error_for_display

    rg.update_attributes(:name => "Other", :threshold => 5)
    assert_equal "Reviewer Group already exists.", rg.error_for_display
  end

end