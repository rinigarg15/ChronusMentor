require_relative './../../../test_helper.rb'
class ThreeSixty::SurveyAssesseesHelperTest < ActionView::TestCase
  
  def test_assigned_survey_assessee
    survey = ThreeSixty::Survey.first
    assessees_count = survey.assessees.count
    assert_equal 3, assessees_count
    assessee = ThreeSixty::SurveyAssessee.new
    assessee.member_id = members(:student_1).id
    assessee.three_sixty_survey_id = survey.id
    assessee.save!
    ans = assigned_survey_assessees(survey)

    survey = ThreeSixty::Survey.first
    assert_match  "#{survey.assessees.first.name}",ans
    ThreeSixty::Survey.first.assessees.destroy_all
    survey = ThreeSixty::Survey.first    
    ans = assigned_survey_assessees(survey)
    survey.assessees.destroy_all    
    assert_match "None", ans
    assessee = ThreeSixty::SurveyAssessee.new
    survey = ThreeSixty::Survey.first
    assessee.member_id = members(:f_admin).id
    assessee.three_sixty_survey_id = survey.id
    assessee.save!
    ans = assigned_survey_assessees(survey)
    assert_match members(:f_admin).name, ans
  end

  def test_three_sixty_text_answers_for
    survey = three_sixty_surveys(:survey_1)
    survey_question = survey.survey_questions.find_by(three_sixty_question_id: three_sixty_questions(:team_work_1).id)
    reviewers = survey.survey_assessees.first.reviewers.group_by(&:three_sixty_survey_reviewer_group_id)
    answers = three_sixty_text_answers_for(survey.survey_reviewer_groups.last, survey_question, reviewers)
    assert_equal_unordered [three_sixty_survey_answers(:answer_6), three_sixty_survey_answers(:answer_8)], answers
  end

  def test_three_sixty_get_competency_additional_data
    survey = three_sixty_surveys(:survey_1)
    survey_assessee = survey.survey_assessees.first
    survey_question = survey.survey_questions.find_by(three_sixty_question_id: three_sixty_questions(:listening_1).id)
    survey_competency = ThreeSixty::SurveyCompetency.find(survey_question.three_sixty_survey_competency_id)
    competency_infos = survey_assessee.survey_assessee_competency_infos
    rating_answers_for_self = survey_assessee.self_reviewer.answers.of_rating_type
    reviewer_group_for_self = programs(:org_primary).three_sixty_reviewer_groups.of_self_type.first
    self.stubs(:three_sixty_competency_average_per_group).at_least(1).returns([0.0, 0.0, 0.0])
    assert_equal [5.0, 3.6, 0.0, 0.0, 0.0], three_sixty_get_competency_additional_data([], [], survey_competency, competency_infos, reviewer_group_for_self)
    assert_equal [0.0, 0.0, 0.0, 0.0, 0.0], three_sixty_get_competency_additional_data([], [], survey_competency, [], [])
  end

  def test_three_sixty_reviewer_group_lables
    survey = three_sixty_surveys(:survey_1)
    survey_assessee = survey.survey_assessees.first
    survey_reviewer_groups = survey.survey_reviewer_groups.excluding_self_type
    survey_question = survey.survey_questions.find_by(three_sixty_question_id: three_sixty_questions(:listening_1).id)
    reviewers = survey_assessee.reviewers.group_by(&:three_sixty_survey_reviewer_group_id)
    reviewers_per_group = three_sixty_report_reviewers_per_group(survey_reviewer_groups, reviewers)
    reviewer_group_lables = three_sixty_reviewer_group_lables(survey_reviewer_groups, reviewers, survey_question, reviewers_per_group)
    assert_equal 3, reviewer_group_lables.size
    assert_equal "Line Managers (1 of 1)", reviewer_group_lables[1]

    three_sixty_survey_answers(:answer_3).destroy
    reviewers = survey_assessee.reload.reviewers.group_by(&:three_sixty_survey_reviewer_group_id)
    reviewer_group_lables = three_sixty_reviewer_group_lables(survey_reviewer_groups.reload, reviewers, survey_question.reload, reviewers_per_group)
    assert_equal 3, reviewer_group_lables.size
    assert_equal "Line Managers (0 of 1)", reviewer_group_lables[1]

    reviewer_group_lables = three_sixty_reviewer_group_lables(survey_reviewer_groups, [], survey_question, reviewers_per_group)
    assert_equal 3, reviewer_group_lables.size

    assert three_sixty_reviewer_group_lables([], reviewers, survey_question, reviewers_per_group).empty?
  end

  def test_three_sixty_reviewer_group_labels_for_competency
    survey = three_sixty_surveys(:survey_1)
    survey_assessee = survey.survey_assessees.first
    survey_reviewer_groups = survey.survey_reviewer_groups.excluding_self_type
    reviewer_group_labels = three_sixty_reviewer_group_labels_for_competency(survey_reviewer_groups)
    assert_equal 3, reviewer_group_labels.size
    assert_equal "Line Managers", reviewer_group_labels[1]
  end

  def test_three_sixty_average_per_group
    survey = three_sixty_surveys(:survey_1)
    survey_assessee = survey.survey_assessees.first
    survey_reviewer_groups = survey.survey_reviewer_groups.excluding_self_type
    average_reviewer_group_answer_values = survey_assessee.average_reviewer_group_answer_values
    survey_question = survey.survey_questions.find_by(three_sixty_question_id: three_sixty_questions(:listening_1).id)

    assert_equal ["Peer", "Line Manager", "Direct Report"], survey_reviewer_groups.collect(&:name)

    average_per_group = three_sixty_average_per_group(survey_reviewer_groups, average_reviewer_group_answer_values, survey_question)
    assert_equal [3.0, 4.0, 3.0], average_per_group
  end

  def test_three_sixty_competency_average_per_group
    survey = three_sixty_surveys(:survey_1)
    survey_assessee = survey.survey_assessees.first
    survey_reviewer_groups = survey.survey_reviewer_groups.excluding_self_type
    average_competency_reviewer_group_answer_values = survey_assessee.average_competency_reviewer_group_answer_values
    survey_question = survey.survey_questions.find_by(three_sixty_question_id: three_sixty_questions(:listening_1).id)
    survey_competency = ThreeSixty::SurveyCompetency.find(survey_question.three_sixty_survey_competency_id)
    assert_equal ["Peer", "Line Manager", "Direct Report"], survey_reviewer_groups.collect(&:name)
    average_per_group = three_sixty_competency_average_per_group(survey_reviewer_groups, average_competency_reviewer_group_answer_values, survey_competency)
    assert_equal [3.0, 4.0, 3.0], average_per_group
  end

  def test_three_sixty_get_data_for_question_or_competency
    survey = three_sixty_surveys(:survey_1)
    survey_assessee = survey.survey_assessees.first
    survey_reviewer_groups = survey.survey_reviewer_groups.excluding_self_type
    reviewer_group_for_self = programs(:org_primary).three_sixty_reviewer_groups.of_self_type.first
    question = three_sixty_questions(:listening_1)
    question_percentiles = survey_assessee.question_percentiles

    assert_equal [100.0, 100.0, 100.0, 100.0, 100.0], three_sixty_get_data_for_question_or_competency(question_percentiles, question, survey_reviewer_groups, reviewer_group_for_self)
    assert_equal [0.0, 0.0, 0.0, 0.0, 0.0], three_sixty_get_data_for_question_or_competency([], question, survey_reviewer_groups, reviewer_group_for_self)
  end

  def test_three_sixty_get_question_additional_data
    survey = three_sixty_surveys(:survey_1)
    survey_assessee = survey.survey_assessees.first
    survey_question = survey.survey_questions.find_by(three_sixty_question_id: three_sixty_questions(:listening_1).id)
    question_infos = survey_assessee.survey_assessee_question_infos
    rating_answers_for_self = survey_assessee.self_reviewer.answers.of_rating_type

    self.stubs(:three_sixty_average_per_group).at_least(1).returns([0.0, 0.0, 0.0])
    assert_equal [5.0, 3.6, 0.0, 0.0, 0.0], three_sixty_get_question_additional_data([], [], survey_question, question_infos, rating_answers_for_self)
    assert_equal [0.0, 0.0, 0.0, 0.0, 0.0], three_sixty_get_question_additional_data([], [], survey_question, [], [])
  end

  def test_three_sixty_report_reviewers_per_group
    survey = three_sixty_surveys(:survey_1)
    survey_assessee = survey.survey_assessees.first
    survey_reviewer_groups = survey.survey_reviewer_groups.excluding_self_type
    reviewers = survey_assessee.reviewers.group_by(&:three_sixty_survey_reviewer_group_id)

    reviewer_group_2 = programs(:org_primary).three_sixty_reviewer_groups.find_by(name: ThreeSixty::ReviewerGroup::DefaultName::LINE_MANAGER)
    reviewer_group_3 = programs(:org_primary).three_sixty_reviewer_groups.find_by(name: ThreeSixty::ReviewerGroup::DefaultName::PEER)
    reviewer_group_4 = programs(:org_primary).three_sixty_reviewer_groups.find_by(name: ThreeSixty::ReviewerGroup::DefaultName::DIRECT_REPORT)
    survey_reviewer_group_2 = survey.survey_reviewer_groups.find_by(three_sixty_reviewer_group_id: reviewer_group_2.id)
    survey_reviewer_group_3 = survey.survey_reviewer_groups.find_by(three_sixty_reviewer_group_id: reviewer_group_3.id)
    survey_reviewer_group_4 = survey.survey_reviewer_groups.find_by(three_sixty_reviewer_group_id: reviewer_group_4.id)

    report_reviewers_per_group = three_sixty_report_reviewers_per_group(survey_reviewer_groups, reviewers)
    assert_equal 1, report_reviewers_per_group[survey_reviewer_group_2.id]
    assert_equal 1, report_reviewers_per_group[survey_reviewer_group_3.id]
    assert_equal 2, report_reviewers_per_group[survey_reviewer_group_4.id]
  end

  def test_three_sixty_report_reviewers_per_group_text
    survey = three_sixty_surveys(:survey_1)
    survey_assessee = survey.survey_assessees.first
    survey_reviewer_groups = survey.survey_reviewer_groups.excluding_self_type
    reviewers = survey_assessee.reviewers.group_by(&:three_sixty_survey_reviewer_group_id)
    reviewers_per_group = three_sixty_report_reviewers_per_group(survey_reviewer_groups, reviewers)

    assert_equal "", three_sixty_report_reviewers_per_group_text([], [])
    assert_equal "1 Peer, 1 Line Manager and 2 Direct Reports", three_sixty_report_reviewers_per_group_text(survey_reviewer_groups, reviewers_per_group)
  end
end