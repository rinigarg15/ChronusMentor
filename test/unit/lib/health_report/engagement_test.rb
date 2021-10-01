require_relative './../../../test_helper'

class HealthReport::EngagementTest < ActiveSupport::TestCase

  def test_compute_engagement
    program = programs(:albers)
    program.scraps.collect(&:destroy)
    program.update_attribute(:inactivity_tracking_period, 1.month)
    assert_equal 6, program.groups.active.count
    assert_equal 5, program.groups.with_status(Group::Status::ACTIVE).count
    assert_equal 1, program.groups.with_status(Group::Status::INACTIVE).count
    active_group_1 = groups(:mygroup)
    active_group_2 = groups(:group_2)

    engagement = HealthReport::Engagement.new(program)
    engagement.compute
    assert_equal 0, engagement.posts_per_connection.value
    assert_floats_equal 0.8333333333333334, engagement.active_connections.value
    assert engagement.overall_satisfaction.no_data?
    assert_equal_hash( {
      "Online" => 0.0,
      "Chat" => 0.0,
      "Phone" => 0.0,
      "Email" => 0.0,
      "Face_to_Face" => 0.0
    }, engagement.connection_mode.distribution)

    program.update_attribute(:created_at, 1.month.ago)
    active_group_1.update_attribute(:created_at, 3.weeks.ago)
    active_group_2.update_attribute(:created_at, 3.weeks.ago)
    create_scrap(group: active_group_1)
    create_scrap(group: active_group_1)
    create_scrap(group: active_group_1)
    create_scrap(group: active_group_2)
    engagement = HealthReport::Engagement.new(program)
    engagement.compute
    assert_floats_equal 0.06666666666666667, engagement.posts_per_connection.value

    group_forum_setup
    group_user = @group.mentors.first
    topic = create_topic(forum: @forum, user: group_user)
    create_post(topic: topic, user: group_user)
    create_post(topic: topic, user: group_user)
    engagement = HealthReport::Engagement.new(program)
    engagement.compute
    assert_floats_equal 0.1, engagement.posts_per_connection.value

    feedback_survey = program.feedback_survey
    effectiveness_question = feedback_survey.survey_questions.find_by(question_mode: CommonQuestion::Mode::EFFECTIVENESS)
    connectivity_question = feedback_survey.survey_questions.find_by(question_mode: CommonQuestion::Mode::CONNECTIVITY)
    response_1 = Survey::SurveyResponse.new(feedback_survey, user_id: active_group_1.mentors.first.id, group_id: active_group_1.id)
    response_2 = Survey::SurveyResponse.new(feedback_survey, user_id: active_group_2.students.first.id, group_id: active_group_2.id)
    response_1.save_answers(effectiveness_question.id => "Very good", connectivity_question.id => "Phone")
    response_2.save_answers(effectiveness_question.id => "Poor", connectivity_question.id => "Face to face meetings")
    engagement = HealthReport::Engagement.new(program)
    engagement.compute
    assert_floats_equal 0.625, engagement.overall_satisfaction.value
    assert_equal_hash( {
      "Online" => 0.0,
      "Chat" => 0.0,
      "Phone" => 0.5,
      "Email" => 0.0,
      "Face_to_Face" => 0.5
    }, engagement.connection_mode.distribution)

    active_group_2.update_attribute(:status, Group::Status::INACTIVE)
    engagement = HealthReport::Engagement.new(program)
    engagement.compute
    assert_floats_equal 0.6666666666666666, engagement.active_connections.value

    active_group_1.terminate!(users(:f_admin), "Reason", program.permitted_closure_reasons.first.id)
    engagement = HealthReport::Engagement.new(program)
    engagement.compute
    assert_floats_equal 0.6, engagement.active_connections.value
    assert_floats_equal 0.02, engagement.posts_per_connection.value
    assert_equal 1, engagement.post_history.value
    assert_equal 1, engagement.post_history.last_month
    assert_floats_equal 0.625, engagement.overall_satisfaction.value
    assert_equal_hash( {
      "Online" => 0.0,
      "Chat" => 0.0,
      "Phone" => 0.5,
      "Email" => 0.0,
      "Face_to_Face" => 0.5
    }, engagement.connection_mode.distribution)

    program.update_attribute(:inactivity_tracking_period, nil)
    engagement = HealthReport::Engagement.new(program)
    engagement.compute
    assert engagement.active_connections.no_data?
    assert engagement.overall_satisfaction.no_data?
    assert engagement.connection_mode.no_data?
  end

  def test_no_data_for_overall_satisfaction_and_connection_mode
    program = programs(:albers)
    program.update_attribute :inactivity_tracking_period, 1.month
    feedback_survey = program.feedback_survey
    feedback_survey.survey_questions.find_by(question_mode: CommonQuestion::Mode::EFFECTIVENESS).destroy

    engagement = HealthReport::Engagement.new(program)
    engagement.compute
    assert engagement.overall_satisfaction.no_data?
    assert engagement.connection_mode.no_data?
  end
end