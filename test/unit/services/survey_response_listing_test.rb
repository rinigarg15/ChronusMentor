require_relative './../../test_helper.rb'

class SurveyResponseListingTest < ActiveSupport::TestCase

  def test_get_survey_questions_for_meeting_or_group
    group_setup
    srl = SurveyResponseListing.new(@program, @group, {survey_id: @survey.id})
    questions = @survey.survey_questions.select(["common_questions.id, survey_id, question_type"]).includes(:translations, rating_questions: :translations, question_choices: :translations)
    test_questions = srl.get_survey_questions_for_meeting_or_group

    questions.each_with_index do |question, index|
      assert_equal question.id, test_questions[index].id
      assert_equal question.question_text, test_questions[index].question_text
      assert_equal question.survey_id, test_questions[index].survey_id
    end
  end

  def test_get_user_for_meeting_or_group
    group_setup
    srl = SurveyResponseListing.new(@program, @group, {user_id: @user.id})
    assert_equal @user, srl.get_user_for_meeting_or_group
  end

  def test_get_survey_answers_for_meeting_or_group
    group_setup
    srl = SurveyResponseListing.new(@program, @group, {survey_id: @survey.id, user_id: @user.id, response_id: @response_id})
    answers = @group.survey_answers.select("common_answers.id, common_question_id, answer_text, common_answers.last_answered_at").index_by(&:common_question_id)
    test_answers = srl.get_survey_answers_for_meeting_or_group
    answers.each do |key, val|
      assert_equal_hash val.attributes, test_answers[key].attributes
    end
  end

  def group_setup
    @user = users(:f_student)
    @mentor = users(:f_mentor)
    @program = programs(:albers)
    @group = create_group(:students => [@user], :mentor => @mentor, :program => @program)
    @program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    @mentoring_model = @program.default_mentoring_model
    @mentoring_model.update_attributes(:should_sync => true)
    @group.update_attribute(:mentoring_model_id, @mentoring_model.id)
    @survey = programs(:albers).surveys.find_by(name: "Partnership Effectiveness")
    create_matrix_survey_question({survey: @survey})
    tem_task = create_mentoring_model_task_template
    tem_task.update_attributes!({action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: @survey.id, :role => @program.roles.with_name([RoleConstants::MENTOR_NAME]).first })
    MentoringModel.trigger_sync(@mentoring_model.id, I18n.locale)

    @response_id = SurveyAnswer.maximum(:response_id).to_i + 1
    @user = @group.mentors.first
    @task = @group.mentoring_model_tasks.reload.where(:action_item_type => MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY).first
    @task.action_item.survey_questions.where(:question_type => [CommonQuestion::Type::STRING , CommonQuestion::Type::TEXT, CommonQuestion::Type::MULTI_STRING]).each do |ques|
      ans = @task.survey_answers.new(:user => @user, :response_id => @response_id, :answer_text => "lorem ipsum", :last_answered_at => Time.now.utc)
      ans.survey_question = ques
      ans.save!
    end
    @task.action_item.survey_questions_with_matrix_rating_questions.matrix_rating_questions.each do |ques|
      ans = @task.survey_answers.new(:user => @user, :response_id => @response_id, :answer_text => "Good", :last_answered_at => Time.now.utc)
      ans.survey_question = ques
      ans.save!
    end
  end
end