require_relative './../../test_helper.rb'

class ThreeSixty::SurveyTest < ActiveSupport::TestCase
  def test_belongs_to_organization
    assert_equal programs(:org_primary), three_sixty_surveys(:survey_1).organization
  end

  def test_belongs_to_program
    assert_equal programs(:albers), three_sixty_surveys(:survey_1).program
  end

  def test_has_many_survey_competencies
    assert_equal 2, three_sixty_surveys(:survey_1).survey_competencies.size
    assert_difference "ThreeSixty::SurveyCompetency.count", -2 do
      three_sixty_surveys(:survey_1).destroy
    end
  end

  def test_has_many_competencies
    assert_equal 2, three_sixty_surveys(:survey_1).competencies.size
    assert_no_difference "ThreeSixty::Competency.count" do
      three_sixty_surveys(:survey_1).destroy
    end
  end

  def test_has_many_survey_questions
    assert_equal 4, three_sixty_surveys(:survey_1).survey_questions.size
    assert_difference "ThreeSixty::SurveyQuestion.count", -4 do
      three_sixty_surveys(:survey_1).destroy
    end
  end

  def test_has_many_survey_oeqs
    assert_equal 2, three_sixty_surveys(:survey_1).survey_oeqs.size
  end

  def test_has_many_questions
    assert_equal 4, three_sixty_surveys(:survey_1).questions.size
    assert_no_difference "ThreeSixty::Question.count" do
      three_sixty_surveys(:survey_1).destroy
    end
  end

  def test_has_many_open_ended_questions
    assert_equal 2, three_sixty_surveys(:survey_1).open_ended_questions.size
  end

  def test_has_many_answers
    assert_equal 10, three_sixty_surveys(:survey_1).answers.size
    assert_difference "ThreeSixty::SurveyAnswer.count", -10 do
      three_sixty_surveys(:survey_1).destroy
    end
  end

  def test_has_many_survey_assessees
    assert_equal 3, three_sixty_surveys(:survey_1).survey_assessees.size
    assert_difference "ThreeSixty::SurveyAssessee.count", -3 do
      three_sixty_surveys(:survey_1).destroy
    end
  end

  def test_has_many_assessees
    assert_equal 3, three_sixty_surveys(:survey_1).assessees.size
    assert_no_difference "Member.count" do
      three_sixty_surveys(:survey_1).destroy
    end
  end

  def test_has_many_survey_reviewer_groups
    assert_equal 4, three_sixty_surveys(:survey_1).survey_reviewer_groups.size
    assert_difference "ThreeSixty::SurveyReviewerGroup.count", -4 do
      three_sixty_surveys(:survey_1).destroy
    end
  end

  def test_has_many_reviewer_groups
    assert_equal 4, three_sixty_surveys(:survey_1).reviewer_groups.size
    assert_no_difference "ThreeSixty::ReviewerGroup.count" do
      three_sixty_surveys(:survey_1).destroy
    end
  end

  def test_has_many_reviewers
    assert_equal 15, three_sixty_surveys(:survey_1).reviewers.size
    assert_difference "ThreeSixty::SurveyReviewer.count", -15 do
      three_sixty_surveys(:survey_1).destroy
    end
  end

  def test_presence_of_organization
    survey = ThreeSixty::Survey.new(:title => 'Some Text')
    survey.save
    assert_equal ["can't be blank"], survey.errors[:organization_id] 
  end

  def test_presence_of_title
    survey = programs(:org_primary).three_sixty_surveys.new
    survey.save
    assert_equal ["can't be blank"], survey.errors[:title]
  end

  def test_uniqueness_of_title_wrt_org
    survey_1 = programs(:org_primary).three_sixty_surveys.new(:title => 'Survey For Level 1 Employees')
    survey_1.save
    assert_equal ["title must be unique"], survey_1.errors[:title]

    survey_2 = programs(:org_anna_univ).three_sixty_surveys.new(:title => 'Survey For Level 1 Employees')
    survey_2.save
    assert survey_2.valid?
  end

  def test_validity_of_reviewers_addition_type
    survey = programs(:org_primary).three_sixty_surveys.new(:title => 'Survey Title for test', :reviewers_addition_type => nil)
    survey.save
    assert_equal ["can't be blank", "is not included in the list"], survey.errors[:reviewers_addition_type]
    survey.reviewers_addition_type = 2
    survey.save
    assert_equal ["is not included in the list"], survey.errors[:reviewers_addition_type]
  end

  def test_expiry_date_not_in_past
    survey = programs(:org_primary).three_sixty_surveys.new
    survey.expiry_date = Time.now + 3.days
    survey.save
    assert_equal "can't be blank", survey.errors.first[1]
  end

  def test_program_belongs_to_organizaion
    s = three_sixty_surveys(:survey_3)
    assert_equal programs(:org_primary), s.organization
    s.program = programs(:org_anna_univ).programs.first
    s.save
    assert_equal ["program should belong to organization"], s.errors[:program]
  end

  def test_may_publish
    survey = three_sixty_surveys(:survey_1)
    assert survey.may_publish?

    survey.update_attribute(:expiry_date, 3.days.ago)
    assert_false survey.reload.may_publish?

    survey.update_attribute(:expiry_date, 3.days.from_now)
    assert_difference "ThreeSixty::SurveyReviewerGroup.count", -4 do
      survey.survey_reviewer_groups.destroy_all
    end
    assert_false survey.reload.may_publish?

    assert_difference "ThreeSixty::SurveyReviewerGroup.count", 5 do
      survey.reviewer_groups = survey.organization.three_sixty_reviewer_groups
    end
    assert_difference "ThreeSixty::SurveyQuestion.count", -4 do
      survey.survey_questions.destroy_all
    end
    assert_false survey.reload.may_publish?

    survey.add_question(three_sixty_questions(:listening_1))
    assert_difference "ThreeSixty::SurveyAssessee.count", -3 do
      survey.survey_assessees.destroy_all
    end
    assert_false survey.reload.may_publish?

    survey.assessees = [members(:f_admin)]
    assert survey.reload.may_publish?

    survey.publish!
    assert_false survey.reload.may_publish?
  end

  def test_add_competency
    assert_equal 2, three_sixty_surveys(:survey_1).competencies.size
    assert_equal 4, three_sixty_surveys(:survey_1).questions.size
    assert_false three_sixty_surveys(:survey_1).competencies.include?(three_sixty_competencies(:delegating))
    assert_equal 2, three_sixty_competencies(:delegating).questions.size

    three_sixty_surveys(:survey_1).add_competency(three_sixty_competencies(:delegating))
    assert_equal 3, three_sixty_surveys(:survey_1).competencies.size
    assert_equal 6, three_sixty_surveys(:survey_1).questions.size

    sc = three_sixty_surveys(:survey_1).add_competency(three_sixty_competencies(:listening))
    assert_false sc.valid?
    assert_equal 3, three_sixty_surveys(:survey_1).competencies.size
    assert_equal 6, three_sixty_surveys(:survey_1).questions.size
  end

  def test_add_question
    assert_equal 4, three_sixty_surveys(:survey_1).questions.size
    assert_equal 2, three_sixty_surveys(:survey_1).competencies.size
    assert_false three_sixty_surveys(:survey_1).questions.include?(three_sixty_questions(:delegating_1))
    assert_false three_sixty_surveys(:survey_1).competencies.include?(three_sixty_competencies(:delegating))

    three_sixty_surveys(:survey_1).add_question(three_sixty_questions(:delegating_1))
    assert_equal 5, three_sixty_surveys(:survey_1).reload.questions.size
    assert_equal 3, three_sixty_surveys(:survey_1).competencies.size
    assert three_sixty_surveys(:survey_1).questions.include?(three_sixty_questions(:delegating_1))
    assert three_sixty_surveys(:survey_1).competencies.include?(three_sixty_competencies(:delegating))

    three_sixty_surveys(:survey_1).add_question(three_sixty_questions(:delegating_1))
    assert_equal 5, three_sixty_surveys(:survey_1).reload.questions.size
    assert_equal 3, three_sixty_surveys(:survey_1).competencies.size

    three_sixty_surveys(:survey_1).add_question(three_sixty_questions(:oeq_3))
    assert_equal 6, three_sixty_surveys(:survey_1).reload.questions.size
    assert_equal 3, three_sixty_surveys(:survey_1).competencies.size
  end

  def test_notify_assessees
    survey = three_sixty_surveys(:survey_1)
    assert_false survey.published?
    assert_no_emails do
      assert_no_difference "JobLog.count" do
        survey.notify_assessees
      end
    end

    survey.publish!
    assert_emails 3 do
      assert_difference "JobLog.count", 3 do
        survey.reload.notify_assessees
      end
    end
  end

  def test_notify_reviewers
    survey = three_sixty_surveys(:survey_1)
    survey.update_attribute(:reviewers_addition_type, ThreeSixty::Survey::ReviewersAdditionType::ADMIN_ONLY)
    assert survey.only_admin_can_add_reviewers?
    assert_false survey.published?
    assert_no_emails do
      assert_no_difference "JobLog.count" do
        survey.notify_reviewers
      end
    end

    survey.update_attribute(:reviewers_addition_type, ThreeSixty::Survey::ReviewersAdditionType::ASSESSEE_ONLY)
    survey.publish!
    assert_false survey.only_admin_can_add_reviewers?
    assert_no_emails do
      assert_no_difference "JobLog.count" do
        survey.notify_reviewers
      end
    end

    survey.update_attribute(:reviewers_addition_type, ThreeSixty::Survey::ReviewersAdditionType::ADMIN_ONLY)
    assert survey.only_admin_can_add_reviewers?
    assert_emails 12 do
      assert_difference "JobLog.count", 12 do
        survey.reload.notify_reviewers
      end
    end
  end

  def test_not_expired
    survey = three_sixty_surveys(:survey_1)
    assert survey.expiry_date > Time.now.utc.to_date
    assert survey.not_expired?

    survey.update_attribute(:expiry_date, nil)
    assert survey.reload.not_expired?

    survey.update_attribute(:expiry_date, 3.days.ago.to_date)
    assert_false survey.reload.not_expired?

    survey.update_attribute(:expiry_date, Time.now.utc.to_date)
    assert survey.reload.not_expired?
  end

  def test_survey_reviewer_group_for_self
    survey = three_sixty_surveys(:survey_1)
    srg = survey.survey_reviewer_group_for_self
    assert srg.reviewer_group.is_for_self?

    assert_difference "ThreeSixty::SurveyReviewerGroup.count", -4 do
      survey.survey_reviewer_groups.destroy_all
    end
    assert_nil survey.reload.survey_reviewer_group_for_self
  end

  def test_create_default_reviewer_group
    survey = three_sixty_surveys(:survey_1)

    assert_difference "ThreeSixty::SurveyReviewerGroup.count", -4 do
      survey.survey_reviewer_groups.destroy_all
    end

    assert_difference "ThreeSixty::SurveyReviewerGroup.count", 1 do
      survey.reload.create_default_reviewer_group
    end

    srg = survey.survey_reviewer_group_for_self
    assert srg.reviewer_group.is_for_self?

    assert_raise(ActiveRecord::RecordInvalid) do
      survey.create_default_reviewer_group
    end
  end

  def test_add_reviewer_groups
    assert_equal 4, three_sixty_surveys(:survey_1).survey_reviewer_groups.size
    assert_difference "ThreeSixty::SurveyReviewer.count", -12 do 
      three_sixty_surveys(:survey_1).add_reviewer_groups([])
    end
    assert_equal 1, three_sixty_surveys(:survey_1).survey_reviewer_groups.size
    assert three_sixty_surveys(:survey_1).survey_reviewer_group_for_self.present?

    three_sixty_surveys(:survey_1).reload.add_reviewer_groups([three_sixty_reviewer_groups(:three_sixty_reviewer_groups_2).name, three_sixty_reviewer_groups(:three_sixty_reviewer_groups_3).name])
    assert_equal 3, three_sixty_surveys(:survey_1).survey_reviewer_groups.size
    assert three_sixty_surveys(:survey_1).survey_reviewer_group_for_self.present?
    assert three_sixty_surveys(:survey_1).reviewer_groups.include?(three_sixty_reviewer_groups(:three_sixty_reviewer_groups_2))
    assert three_sixty_surveys(:survey_1).reviewer_groups.include?(three_sixty_reviewer_groups(:three_sixty_reviewer_groups_3))
  end

  def test_only_admin_can_add_reviewers
    survey = programs(:org_primary).three_sixty_surveys.new(:title => 'A new survey')
    assert survey.only_admin_can_add_reviewers?
    survey.update_attribute(:reviewers_addition_type, ThreeSixty::Survey::ReviewersAdditionType::ASSESSEE_ONLY)
    assert_false survey.only_admin_can_add_reviewers?
  end

  def test_only_assessee_can_add_reviewers
    survey = programs(:org_primary).three_sixty_surveys.new(:title => 'A new survey')
    assert_false survey.only_assessee_can_add_reviewers?
    survey.update_attribute(:reviewers_addition_type, ThreeSixty::Survey::ReviewersAdditionType::ASSESSEE_ONLY)
    assert survey.only_assessee_can_add_reviewers?
  end

  def test_after_save
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(ThreeSixty::SurveyAssessee, [1, 2, 3])
    survey = three_sixty_surveys(:survey_1)
    survey.update_attributes!(title: "Test Title")
  end
end