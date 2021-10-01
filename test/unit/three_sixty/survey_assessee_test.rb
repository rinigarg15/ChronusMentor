require_relative './../../test_helper.rb'

class ThreeSixty::SurveyAssesseeTest < ActiveSupport::TestCase
  def test_belongs_to_assessee
    assert_equal members(:f_admin), three_sixty_survey_assessees(:three_sixty_survey_assessees_1).assessee
  end

  def test_belongs_to_survey
    assert_equal three_sixty_surveys(:survey_1), three_sixty_survey_assessees(:three_sixty_survey_assessees_1).survey
  end

  def test_has_many_reviewers
    assert_equal 5, three_sixty_survey_assessees(:three_sixty_survey_assessees_1).reviewers.size
    assert_difference "ThreeSixty::SurveyReviewer.count", -5 do
      three_sixty_survey_assessees(:three_sixty_survey_assessees_1).destroy
    end
  end

  def test_has_many_survey_assessee_question_infos
    assert_equal 5, three_sixty_survey_assessees(:three_sixty_survey_assessees_1).survey_assessee_question_infos.size
    assert_difference "ThreeSixty::SurveyAssesseeQuestionInfo.count", -5 do
      three_sixty_survey_assessees(:three_sixty_survey_assessees_1).destroy
    end
  end

  def test_has_many_survey_assessee_competency_infos
    assert_equal 5, three_sixty_survey_assessees(:three_sixty_survey_assessees_1).survey_assessee_competency_infos.size
    assert_difference "ThreeSixty::SurveyAssesseeCompetencyInfo.count", -5 do
      three_sixty_survey_assessees(:three_sixty_survey_assessees_1).destroy
    end
  end

  def test_presence_of_member
    survey_assessee = three_sixty_surveys(:survey_1).survey_assessees.new
    survey_assessee.save

    assert_equal ["choose users from the autocomplete list"], survey_assessee.errors[:member_id]
  end

  def test_presence_of_survey
    survey_assessee = members(:f_admin).three_sixty_survey_assessees.new
    assert_raise NoMethodError do
      survey_assessee.save
    end
  end

  def test_uniqueness_member_wrt_survey
    assert three_sixty_surveys(:survey_1).assessees.include?(members(:f_admin))

    survey_assessee = three_sixty_surveys(:survey_1).survey_assessees.new(:assessee => members(:f_admin))
    survey_assessee.save
    assert_equal ["has already been added"], survey_assessee.errors[:member_id]
  end

  def test_assessee_and_survey_belong_to_same_organization
    survey = programs(:org_anna_univ).three_sixty_surveys.create!(:title => "Diffetent org survey")
    survey_assessee = survey.survey_assessees.new(:assessee => members(:f_admin))
    survey_assessee.save
    assert_equal ["member being assessed should belong to the same organization as the survey"], survey_assessee.errors[:member_id]
  end

  def test_assessee_and_survey_belong_to_same_program
    survey = three_sixty_surveys(:survey_1)
    assert_equal programs(:albers), survey.program
    survey_assessee = survey.survey_assessees.new(:assessee => members(:nwen_admin))
    survey_assessee.save
    assert_equal ["member being assessed should belong to the same program as the survey"], survey_assessee.errors[:member_id]
  end

  def test_name
    assert_equal three_sixty_survey_assessees(:three_sixty_survey_assessees_1).assessee.name, three_sixty_survey_assessees(:three_sixty_survey_assessees_1).name
  end

  def test_scope_accessible
    ThreeSixty::SurveyAssessee.accessible.destroy_all

    three_sixty_surveys(:survey_1).publish!
    assert_equal three_sixty_surveys(:survey_1).survey_assessees, ThreeSixty::SurveyAssessee.accessible

    three_sixty_surveys(:survey_1).update_attribute(:expiry_date, nil)
    assert_equal three_sixty_surveys(:survey_1).survey_assessees, ThreeSixty::SurveyAssessee.accessible

    three_sixty_surveys(:survey_1).update_attribute(:expiry_date, 2.weeks.ago)
    assert ThreeSixty::SurveyAssessee.accessible.empty?
  end

  def test_scope_for_member
    assert_equal members(:f_admin).three_sixty_survey_assessees, ThreeSixty::SurveyAssessee.for_member(members(:f_admin))
  end

  def test_self_reviewer
    sr = three_sixty_survey_assessees(:three_sixty_survey_assessees_1).self_reviewer
    assert sr.for_self?
  end

  def test_create_self_reviewer
    survey_assessee = three_sixty_survey_assessees(:three_sixty_survey_assessees_1)
    assert_no_difference "ThreeSixty::SurveyReviewer.count" do
      assert_raise ActiveRecord::RecordInvalid do
        survey_assessee.create_self_reviewer!
      end
    end

    assert_difference "ThreeSixty::SurveyReviewer.count", -5 do
      survey_assessee.reviewers.destroy_all
    end

    assert_difference "ThreeSixty::SurveyReviewer.count", 1 do
      survey_assessee.create_self_reviewer!
    end

    assert survey_assessee.reviewers.first.for_self?
  end

  def test_notify
    survey_assessee = three_sixty_survey_assessees(:three_sixty_survey_assessees_1)
    assert_false survey_assessee.self_reviewer.invite_sent?

    assert_emails 1 do
      survey_assessee.notify
    end
    assert survey_assessee.reload.self_reviewer.invite_sent?

    assert_no_emails do
      survey_assessee.notify
    end
  end

  def test_notify_pending_reviewers
    survey_assessee = three_sixty_survey_assessees(:three_sixty_survey_assessees_1)
    assert_emails 5 do
      assert_difference "JobLog.count", 5 do
        survey_assessee.notify_pending_reviewers
      end
    end

    assert_no_emails do
      assert_no_difference "JobLog.count" do
        survey_assessee.notify_pending_reviewers
      end
    end

    survey_assessee.reviewers.create!(:survey_reviewer_group => three_sixty_survey_reviewer_groups(:three_sixty_survey_reviewer_groups_2), :name => 'some text', :email => "new_pending_reviewer@example.com")

    assert_emails 1 do
      assert_difference "JobLog.count", 1 do
        survey_assessee.reload.notify_pending_reviewers
      end
    end
    email = ActionMailer::Base.deliveries.last
    mail_content = get_html_part_from(email)
    assert_match "#{survey_assessee.survey.title}: Invitation to assess #{survey_assessee.assessee.name}", email.subject
    assert_match "You are requested to provide developmental feedback for #{survey_assessee.assessee.name} as part of a 360 degree feedback assessment.", mail_content
    assert_match "Completing the review will take only a few minutes. Your individual responses are kept strictly confidential and will not be shared with anyone unless you are their Manager.", mail_content
    assert_match "#{survey_assessee.assessee.name} will only have access to aggregate scores.", mail_content
    assert_match "Complete the survey", mail_content
    assert_match "/reviewers/show_reviewers", mail_content
  end

  def test_is_for
    assert three_sixty_survey_assessees(:three_sixty_survey_assessees_1).is_for?(members(:f_admin))
    assert_false three_sixty_survey_assessees(:three_sixty_survey_assessees_1).is_for?(members(:f_student))
  end

  def test_threshold_met
    survey_assessee = three_sixty_survey_assessees(:three_sixty_survey_assessees_1)
    survey = survey_assessee.survey
    assert_equal_unordered [three_sixty_survey_reviewer_groups(:three_sixty_survey_reviewer_groups_1),
                            three_sixty_survey_reviewer_groups(:three_sixty_survey_reviewer_groups_2),
                            three_sixty_survey_reviewer_groups(:three_sixty_survey_reviewer_groups_3),
                            three_sixty_survey_reviewer_groups(:three_sixty_survey_reviewer_groups_4)], survey.survey_reviewer_groups

    assert_false survey_assessee.threshold_met?

    survey_assessee_reviewer = survey_assessee.reviewers.group_by(&:three_sixty_survey_reviewer_group_id)
    assert_equal 1, survey_assessee_reviewer[three_sixty_reviewer_groups(:three_sixty_reviewer_groups_2).id].size
    assert_equal 1, survey_assessee_reviewer[three_sixty_reviewer_groups(:three_sixty_reviewer_groups_3).id].size
    assert_equal 2, survey_assessee_reviewer[three_sixty_reviewer_groups(:three_sixty_reviewer_groups_4).id].size

    assert_equal 3, three_sixty_survey_reviewer_groups(:three_sixty_survey_reviewer_groups_2).reviewer_group.threshold
    assert_equal 1, three_sixty_survey_reviewer_groups(:three_sixty_survey_reviewer_groups_3).reviewer_group.threshold
    assert_equal 3, three_sixty_survey_reviewer_groups(:three_sixty_survey_reviewer_groups_4).reviewer_group.threshold

    three_sixty_survey_reviewer_groups(:three_sixty_survey_reviewer_groups_2).reviewer_group.update_attribute(:threshold, 1)
    assert_false survey_assessee.reload.threshold_met?

    three_sixty_survey_reviewer_groups(:three_sixty_survey_reviewer_groups_4).reviewer_group.update_attribute(:threshold, 1)
    assert survey_assessee.reload.threshold_met?

    three_sixty_survey_reviewer_groups(:three_sixty_survey_reviewer_groups_4).reviewer_group.update_attribute(:threshold, 2)
    assert survey_assessee.reload.threshold_met?

    survey_assessee.reviewers.except_self.destroy_all
    assert_false survey_assessee.reload.threshold_met?
  end

  def test_survey_assessee_competency_infos
    survey_assessee = three_sixty_survey_assessees(:three_sixty_survey_assessees_1)
    survey = survey_assessee.survey
    competency_infos = survey_assessee.survey_assessee_competency_infos
    assert_equal 5, competency_infos.size
    assert_equal 3.6, competency_infos.first.average_value.to_f.round(2)

    three_sixty_survey_answers(:answer_1).destroy
    competency_infos = survey_assessee.reload.survey_assessee_competency_infos
    assert_equal 4, competency_infos.size
    assert_equal 3.25, competency_infos.first.average_value.to_f.round(2)

    survey.add_competency(three_sixty_competencies(:leadership))
    sq1 = survey.survey_questions.find_by(three_sixty_question_id: three_sixty_questions(:leadership_1).id)
    sq2 = survey.survey_questions.find_by(three_sixty_question_id: three_sixty_questions(:leadership_2).id)
    sq3 = survey.survey_questions.find_by(three_sixty_question_id: three_sixty_questions(:leadership_3).id)

    r1 = survey_assessee.self_reviewer
    r2 = three_sixty_survey_reviewers(:survey_reviewer_2)
    r3 = three_sixty_survey_reviewers(:survey_reviewer_3)
    r1.answers.create!(:survey_question => sq1, :answer_value => 3)
    competency_infos = survey_assessee.reload.survey_assessee_competency_infos
    assert_equal 6, competency_infos.size
    rev_gp_id = ThreeSixty::SurveyReviewerGroup.find(r1.three_sixty_survey_reviewer_group_id).three_sixty_reviewer_group_id
    assert_equal 3.0, competency_infos.where("three_sixty_reviewer_group_id = #{rev_gp_id} and three_sixty_competency_id = #{three_sixty_competencies(:leadership).id}").first.average_value.to_f.round(2)

    r2.answers.create!(:survey_question => sq1, :answer_value => 5)
    r3.answers.create!(:survey_question => sq1, :answer_value => 5)
    competency_infos = survey_assessee.reload.survey_assessee_competency_infos
    assert_equal 8, competency_infos.size
    rev_gp_id = ThreeSixty::SurveyReviewerGroup.find(r2.three_sixty_survey_reviewer_group_id).three_sixty_reviewer_group_id
    assert_equal 5.0, competency_infos.where("three_sixty_reviewer_group_id = #{rev_gp_id} and three_sixty_competency_id = #{three_sixty_competencies(:leadership).id}").first.average_value.to_f.round(2)
    rev_gp_id = ThreeSixty::SurveyReviewerGroup.find(r3.three_sixty_survey_reviewer_group_id).three_sixty_reviewer_group_id
    assert_equal 5.0, competency_infos.where("three_sixty_reviewer_group_id = #{rev_gp_id} and three_sixty_competency_id = #{three_sixty_competencies(:leadership).id}").first.average_value.to_f.round(2)
    assert_equal 4.33, competency_infos.where("three_sixty_reviewer_group_id = 0 and three_sixty_competency_id = #{three_sixty_competencies(:leadership).id}").first.average_value.to_f.round(2)
    r1.answers.create!(:survey_question => sq2, :answer_value => 3)
    competency_infos = survey_assessee.reload.survey_assessee_competency_infos
    assert_equal 8, competency_infos.size
    rev_gp_id = ThreeSixty::SurveyReviewerGroup.find(r1.three_sixty_survey_reviewer_group_id).three_sixty_reviewer_group_id
    assert_equal 3.0, competency_infos.where("three_sixty_reviewer_group_id = #{rev_gp_id} and three_sixty_competency_id = #{three_sixty_competencies(:leadership).id}").first.average_value.to_f.round(2)
    assert_equal 4.0, competency_infos.where("three_sixty_reviewer_group_id = 0 and three_sixty_competency_id = #{three_sixty_competencies(:leadership).id}").first.average_value.to_f.round(2)
    r1.answers.create!(:survey_question => sq3, :answer_value => 5)
    competency_infos = survey_assessee.reload.survey_assessee_competency_infos
    assert_equal 8, competency_infos.size
    rev_gp_id = ThreeSixty::SurveyReviewerGroup.find(r1.three_sixty_survey_reviewer_group_id).three_sixty_reviewer_group_id
    assert_equal 3.67, competency_infos.where("three_sixty_reviewer_group_id = #{rev_gp_id} and three_sixty_competency_id = #{three_sixty_competencies(:leadership).id}").first.average_value.to_f.round(2)
    assert_equal 4.2, competency_infos.where("three_sixty_reviewer_group_id = 0 and three_sixty_competency_id = #{three_sixty_competencies(:leadership).id}").first.average_value.to_f.round(2)

  end

  def test_average_reviewer_group_answer_values
    survey_assessee = three_sixty_survey_assessees(:three_sixty_survey_assessees_1)
    survey = survey_assessee.survey

    reviewer_group_2 = programs(:org_primary).three_sixty_reviewer_groups.find_by(name: ThreeSixty::ReviewerGroup::DefaultName::LINE_MANAGER)
    reviewer_group_3 = programs(:org_primary).three_sixty_reviewer_groups.find_by(name: ThreeSixty::ReviewerGroup::DefaultName::PEER)
    reviewer_group_4 = programs(:org_primary).three_sixty_reviewer_groups.find_by(name: ThreeSixty::ReviewerGroup::DefaultName::DIRECT_REPORT)

    survey_reviewer_group_2 = survey.survey_reviewer_groups.find_by(three_sixty_reviewer_group_id: reviewer_group_2.id)
    survey_reviewer_group_3 = survey.survey_reviewer_groups.find_by(three_sixty_reviewer_group_id: reviewer_group_3.id)
    survey_reviewer_group_4 = survey.survey_reviewer_groups.find_by(three_sixty_reviewer_group_id: reviewer_group_4.id)

    survey_question_1 = survey.survey_questions.find_by(three_sixty_question_id: three_sixty_questions(:listening_1).id)
    average_reviewer_group_answer_values = survey_assessee.average_reviewer_group_answer_values
    assert_equal 4.0, average_reviewer_group_answer_values[[survey_question_1.question.id, survey_reviewer_group_2.id]].first.avg_value.to_f.round(2)
    assert_equal 3.0, average_reviewer_group_answer_values[[survey_question_1.question.id, survey_reviewer_group_3.id]].first.avg_value.to_f.round(2)
    assert_equal 3.0, average_reviewer_group_answer_values[[survey_question_1.question.id, survey_reviewer_group_4.id]].first.avg_value.to_f.round(2)

    reviewer = survey_assessee.reviewers.create!(:name => "XYZ", :email => "XYZ@example.com", :survey_reviewer_group => survey_reviewer_group_2)
    reviewer.answers.create!(:survey_question => survey_question_1, :answer_value => 3)

    average_reviewer_group_answer_values = survey_assessee.reload.average_reviewer_group_answer_values
    assert_equal 3.5, average_reviewer_group_answer_values[[survey_question_1.question.id, survey_reviewer_group_2.id]].first.avg_value.to_f.round(2)
    assert_equal 3.0, average_reviewer_group_answer_values[[survey_question_1.question.id, survey_reviewer_group_3.id]].first.avg_value.to_f.round(2)
    assert_equal 3.0, average_reviewer_group_answer_values[[survey_question_1.question.id, survey_reviewer_group_4.id]].first.avg_value.to_f.round(2)
  end

  def test_question_percentiles
    survey_assessee = three_sixty_survey_assessees(:three_sixty_survey_assessees_1)
    survey = survey_assessee.survey
    survey_question_1 = survey.survey_questions.find_by(three_sixty_question_id: three_sixty_questions(:listening_1).id)
    reviewer = three_sixty_survey_reviewers(:survey_reviewer_7)
    rg_id = reviewer.reviewer_group.id
    self_rg_id = survey.reviewer_groups.of_self_type.first.id

    question_percentiles = survey_assessee.question_percentiles
    assert_equal_unordered [0] + survey.reviewer_groups.pluck(:id), question_percentiles[survey_question_1.question.id].collect(&:three_sixty_reviewer_group_id)
    assert_equal 100.0, question_percentiles[survey_question_1.question.id].first.percentile
    assert_equal 100.0, question_percentiles[survey_question_1.question.id][rg_id].percentile
    assert_equal 100.0, question_percentiles[survey_question_1.question.id][self_rg_id].percentile

    answer = reviewer.answers.create!(:survey_question => survey_question_1, :answer_value => 5)
    question_percentiles_2 = survey_assessee.reload.question_percentiles
    assert_equal 50.0, question_percentiles_2[survey_question_1.question.id].first.percentile
    assert_equal 50.0, question_percentiles_2[survey_question_1.question.id][rg_id].percentile.to_i
    assert_equal 100.0, question_percentiles_2[survey_question_1.question.id][self_rg_id].percentile

    answer.update_attribute(:answer_value, 1)
    question_percentiles_3 = survey_assessee.reload.question_percentiles
    assert_equal 100.0, question_percentiles_3[survey_question_1.question.id].first.percentile
    assert_equal 100.0, question_percentiles_3[survey_question_1.question.id][rg_id].percentile
    assert_equal 100.0, question_percentiles_3[survey_question_1.question.id][self_rg_id].percentile
  end

  def test_competency_percentiles
    survey_assessee = three_sixty_survey_assessees(:three_sixty_survey_assessees_1)
    survey = survey_assessee.survey
    survey_question_1 = survey.survey_questions.find_by(three_sixty_question_id: three_sixty_questions(:listening_1).id)
    reviewer = three_sixty_survey_reviewers(:survey_reviewer_7)
    rg_id = reviewer.reviewer_group.id
    self_rg_id = survey.reviewer_groups.of_self_type.first.id

    competency_percentiles = survey_assessee.competency_percentiles
    survey_competency_1 =  ThreeSixty::SurveyCompetency.find(survey_question_1.three_sixty_survey_competency_id)

    assert_equal 100.0, competency_percentiles[survey_competency_1.competency.id][rg_id].percentile
    assert_equal 100.0, competency_percentiles[survey_competency_1.competency.id][self_rg_id].percentile

    answer = reviewer.answers.create!(:survey_question => survey_question_1, :answer_value => 5)
    competency_percentiles_2 = survey_assessee.reload.competency_percentiles
    assert_equal 50.0, competency_percentiles_2[survey_competency_1.competency.id][rg_id].percentile
    assert_equal 100.0, competency_percentiles_2[survey_competency_1.competency.id][self_rg_id].percentile

    answer.update_attribute(:answer_value, 1)
    competency_percentiles_3 = survey_assessee.reload.competency_percentiles
    assert_equal 100.0, competency_percentiles[survey_competency_1.competency.id][rg_id].percentile
    assert_equal 100.0, competency_percentiles[survey_competency_1.competency.id][self_rg_id].percentile
  end

end