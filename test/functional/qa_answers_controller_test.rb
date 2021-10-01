require_relative './../test_helper.rb'

class QaAnswersControllerTest < ActionController::TestCase
  def setup
    super
    @moderator_role = create_role(:name => 'moderator')
    @answerer_role = create_role(:name => 'answerer')
    @rater_role = create_role(:name => 'rater')
    add_role_permission(@moderator_role, 'manage_answers')
    add_role_permission(@answerer_role, 'answer_question')
    add_role_permission(@answerer_role, 'rate_answer')
    add_role_permission(@answerer_role, 'view_answerers')
    @moderator = create_user(:name => 'moderator', :role_names => ['moderator'])
    @answerer = create_user(:name => 'answerer', :role_names => ['answerer'])
    @rater = create_user(:name => 'rater', :role_names => ['rater'])
    current_program_is :albers
  end

  def test_authentication
    current_user_is :f_student
    programs(:org_primary).enable_feature(FeatureName::ANSWERS, false)

    qa_question = qa_questions(:what)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REPLY_TO_QA, {context_object: qa_question.summary}).never
    assert_permission_denied do
      post :create, xhr: true, params: { :qa_question_id => qa_question.id, :qa_answer => {:content => "Hey your question is right"}}
    end

    qa_answer = create_qa_answer
    assert_permission_denied do
      post :helpful, xhr: true, params: { :qa_question_id => qa_answer.qa_question.id, :id => qa_answer.id}
    end
  end

  def test_create_answer
    current_user_is @answerer
    qa_question = qa_questions(:what)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REPLY_TO_QA, {context_object: qa_question.summary}).once
    assert_difference('QaAnswer.count') do
      post :create, xhr: true, params: { :qa_question_id => qa_question.id, :qa_answer => {:content => "Hey your question is right"}}
    end
    assert_redirected_to qa_question_path(qa_question, format: :js, sort: "id", order: "desc", answer_created: true)

    ans = QaAnswer.last
    assert_equal qa_question, ans.qa_question
    assert_equal @answerer, ans.user
  end

  def test_create_answer_failed
    current_user_is @answerer
    qa_question = qa_questions(:what)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REPLY_TO_QA, {context_object: qa_question.summary}).never
    assert_raise(ActiveRecord::RecordInvalid) do
      assert_no_difference('QaAnswer.count') do
        post :create, xhr: true, params: { :qa_question_id => qa_question.id, :qa_answer => {:content => ""}}
      end
    end
  end

  def test_helpful
    qa_answer = create_qa_answer

    current_user_is @rater
    assert_difference('Rating.count') do
      post :helpful, xhr: true, params: { qa_question_id: qa_answer.qa_question_id, id: qa_answer.id }
    end
    assert_equal 1, qa_answer.rating

    assert_difference('Rating.count', -1) do
      post :helpful, xhr: true, params: { qa_question_id: qa_answer.qa_question_id, id: qa_answer.id }
    end
    assert_equal 0, qa_answer.reload.rating

    assert_no_difference('Rating.count') do
      post :helpful, xhr: true, params: { qa_question_id: qa_answer.qa_question_id, id: 0 }
    end
  end

  # Delete
  def test_do_not_allow_nonadmin_user_other_than_owner_to_delete
    current_user_is :f_mentor
    qa_answer = create_qa_answer
    assert !users(:f_mentor).can_manage_answers?
    assert_permission_denied do
      post :destroy, params: { :qa_question_id => qa_answer.qa_question.id, :id => qa_answer.id}
    end
  end

  def test_should_allow_owner_to_delete
    current_user_is :f_student
    qa_answer = create_qa_answer
    qa_question = qa_answer.qa_question
    # Not a manager. Never mind.
    assert_false users(:f_student).can_manage_answers?
    flag = create_flag(content: qa_answer)
    assert flag.unresolved?
    assert_difference('QaAnswer.count', -1) do
      post :destroy, xhr: true, params: { qa_question_id: qa_answer.qa_question.id, id: qa_answer.id, answer_deleted: true}
    end
    assert_redirected_to qa_question_path(qa_question, format: :js, sort: "id", order: "desc", answer_deleted: true)
    assert_equal Flag::Status::DELETED, flag.reload.status
  end
end
