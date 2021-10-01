require_relative './../../test_helper.rb'

class Connection::QuestionsControllerTest < ActionController::TestCase

  def setup
    super
    programs(:org_primary).enable_feature(FeatureName::CONNECTION_PROFILE, true)
  end

  def test_index_no_feature_case
    current_user_is :foster_admin
    assert_permission_denied do
      get :index
    end
  end

  def test_index_no_permission_case
    current_user_is :f_mentor
    assert_permission_denied do
      get :index
    end
  end

  def test_index
    current_user_is :f_admin
    get :index
    assert_response :success
    assert_match /The Mentoring Connection profile form includes the following fields in addition to the default profile fields \(name, picture\)/, ActionController::Base.helpers.strip_tags(@response.body).squish
    assert_equal programs(:albers).connection_questions, assigns(:connection_questions)
  end

  def test_new
    current_user_is :f_admin
    get :new, xhr: true
    assert_response :success
    assert_equal programs(:albers), assigns(:common_question).program
  end

  def test_create
    summaries(:string_connection_summary_q).destroy!
    current_user_is :f_admin
    assert_difference 'Connection::Question.count' do
      post :create, xhr: true, params: { connection_question: {
        question_text: "How are you?",
        question_type: CommonQuestion::Type::SINGLE_CHOICE,
        is_admin_only: true,
        required: true,
        display_question_in_summary: "1"
      }, common_question: {existing_question_choices_attributes: [{"101"=>{"text" => "Good"}, "102"=>{"text" => "Bad"}, "103"=>{"text" => "Okay"}}], question_choices: {new_order: "101,102,103"}}}
    end
    q = Connection::Question.last
    summary_q = Summary.last
    assert_equal q, assigns(:common_question)
    assert_equal programs(:albers), q.program
    assert_equal CommonQuestion::Type::SINGLE_CHOICE, q.question_type
    assert_equal false, q.allow_other_option?
    assert_equal ["Good", "Bad", "Okay"], q.default_choices
    assert_equal summary_q, programs(:albers).summaries.first
    assert_equal summary_q, q.summary
    assert_equal 1, programs(:albers).summaries.count
    assert q.is_admin_only?
    assert q.required?
  end

  def test_update_success
    question = common_questions(:string_connection_q)

    current_user_is :f_admin
    put :update, xhr: true, params: { :id => question.id, :connection_question => {
      :question_text => "Eurkha",
      :question_type => CommonQuestion::Type::SINGLE_CHOICE,
      :allow_other_option => true,
      :is_admin_only => false,
      :required => true,
      display_question_in_summary: "0"
    }, common_question: {existing_question_choices_attributes: [{"101"=>{"text" => "Good"}, "102"=>{"text" => "Bad"}, "103"=>{"text" => "Okay"}}], question_choices: {new_order: "101,102,103"}}}
    assert_response :success
    question.reload
    assert_equal 'Eurkha', question.question_text
    assert_equal CommonQuestion::Type::SINGLE_CHOICE, question.question_type
    assert question.allow_other_option?
    assert_false question.is_admin_only?
    assert question.required?
    assert_equal ["Good", "Bad", "Okay"], question.default_choices
    assert_nil programs(:albers).summaries.first
    assert_nil question.summary
    assert_equal 0, programs(:albers).summaries.count
  end

  def test_update_failure
    question = common_questions(:string_connection_q)


    current_user_is :f_admin
    put :update, xhr: true, params: { :id => question.id,
      :connection_question => {:question_text => ""}} # Error here
    assert_response :success
    assert assigns(:common_question).errors[:question_text]
    question.reload
    assert_equal "Funding Value", question.question_text
    assert_equal CommonQuestion::Type::STRING, question.question_type
  end

  def test_destroy
    current_user_is :f_admin
    assert_difference 'Connection::Question.count', -1 do
      delete :destroy, xhr: true, params: { :id => common_questions(:string_connection_q).id}
    end
    assert assigns(:summary_present)
  end
  def test_destroy_without_summary_present
    current_user_is :f_admin
    assert_difference 'Connection::Question.count', -1 do
      delete :destroy, xhr: true, params: { :id => common_questions(:single_choice_connection_q).id}
    end
    assert_false assigns(:summary_present)
  end

  def test_sort
    all_questions = programs(:albers).connection_questions
    shuffled_questions = all_questions.sort_by{rand}
    new_order = shuffled_questions.collect(&:id)

    current_user_is :f_admin
    put :sort, xhr: true, params: { :new_order => new_order}
    assert_response :success
    assert_equal new_order, programs(:albers).reload.connection_questions.order("position ASC").collect(&:id)
  end

  def test_no_access_for_program_with_disabled_ongoing_mentoring
    current_user_is :f_admin
    # changing engagement type of program to career based
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_permission_denied do
      get :index
    end
  end
end