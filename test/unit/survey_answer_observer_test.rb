require_relative './../test_helper.rb'

class SurveyAnswerObserverTest < ActiveSupport::TestCase
  def test_survey_id_update
    survey = surveys(:one)
    question = create_survey_question(survey: survey)
    answer = SurveyAnswer.create!({answer_text: "My answer", user: users(:f_student), last_answered_at: Time.now.utc, survey_question: question})

    assert_equal survey.id, answer.survey_id
    assert_equal question.survey_id, answer.survey_id
  end

  def test_survey_responses_count_update
    survey = surveys(:one)

    question = create_survey_question(survey: survey)

    answer = SurveyAnswer.create!({answer_text: "My answer", user: users(:f_student), :response_id => 1, last_answered_at: Time.now.utc, survey_question: question})
    survey.update_total_responses!

    assert_equal 1, survey.reload.total_responses

    Survey.expects(:delay).returns(Survey)
    Survey.expects(:update_total_responses_for_survey!).with(answer.survey_id)
    answer.destroy
  end

  def test_group_and_role_id_before_save
    prog = programs(:albers)
    mentoring_model = prog.default_mentoring_model
    group = groups(:mygroup)
    prog.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    mentoring_model.update_attribute(:should_sync, true)
    group.update_attribute(:mentoring_model_id, mentoring_model.id)
    tem_task1 = create_mentoring_model_engagement_survey_task_template
    membership = group.mentor_memberships.first
    task = group.mentoring_model_tasks.reload.where(:action_item_type => MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, connection_membership_id: membership.id).first
    task.action_item.survey_questions.where(:question_type => [CommonQuestion::Type::STRING , CommonQuestion::Type::TEXT, CommonQuestion::Type::MULTI_STRING]).each do |ques|
      ans = task.survey_answers.new(:user_id => membership.user_id, :answer_text => "lorem ipsum", :last_answered_at => Time.now.utc)
      ans.survey_question = ques
      ans.save!
      assert_equal ans.group_id, group.id
      assert_equal ans.connection_membership_role_id, membership.role_id
    end
    ans = SurveyAnswer.last
    ans.group_id = nil
    ans.save!
    assert_equal ans.group_id, group.id
    assert_equal ans.connection_membership_role_id, membership.role_id
  end

  def test_after_save
    group = groups(:mygroup)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Group, [group.id])
    create_survey_answer(group: group)
  end

  def test_after_destroy
    group = groups(:mygroup)
    survey_answer = create_survey_answer(group: group)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Group, [group.id])
    survey_answer.destroy
  end
end
