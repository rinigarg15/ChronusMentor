require_relative './../../test_helper.rb'

class ThreeSixty::QuestionsControllerTest < ActionController::TestCase
  def test_any_action_without_feature_permission_denied
    assert_false programs(:org_primary).has_feature?(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    assert_permission_denied do    
      post :create
    end

    assert_permission_denied do    
      get :edit, params: { :id => three_sixty_questions(:leadership_1).id}
    end

    assert_permission_denied do    
      put :update, params: { :id => three_sixty_questions(:leadership_1).id}
    end

    assert_permission_denied do    
      delete :destroy, xhr: true, params: { :id => three_sixty_questions(:leadership_1).id}
    end

    assert_permission_denied do
      post :create_and_add_to_survey, xhr: true
    end
  end

  def test_create_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary
    
    post :create
    assert_redirected_to new_session_path
  end

  def test_create_non_admin_permission_denied
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :ram
    
    assert_permission_denied do    
      get :create
    end
  end

  def test_create_failure
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    assert_no_difference "ThreeSixty::Question.count" do
      post :create, xhr: true, params: { :three_sixty_question => {:question_type => ThreeSixty::Question::Type::RATING, :three_sixty_competency_id => programs(:org_primary).three_sixty_competencies.first.id}}
    end
    assert_response :success

    assert_equal ThreeSixty::Question::Type::RATING, assigns(:question).question_type
    assert_nil assigns(:question).title
    assert_equal programs(:org_primary).three_sixty_competencies.first, assigns(:question).competency

    assert_raise NoMethodError do
      post :create, xhr: true, params: { :three_sixty_question => {:title => "a new title", :question_type => ThreeSixty::Question::Type::RATING, :three_sixty_competency_id => 10000}}
    end
  end

  def test_create_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin
    
    assert_difference "ThreeSixty::Question.count", 1 do
      post :create, xhr: true, params: { :three_sixty_question => {:title => "new title", :question_type => ThreeSixty::Question::Type::RATING, :three_sixty_competency_id => programs(:org_primary).three_sixty_competencies.first.id}}
    end

    assert_response :success

    assert_equal ThreeSixty::Question::Type::RATING, assigns(:question).question_type
    assert_equal "new title", assigns(:question).title
    assert_equal programs(:org_primary).three_sixty_competencies.first, assigns(:question).competency
  end

  def test_create_oeq_failure
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin
    
    assert_no_difference "ThreeSixty::Question.count" do
      post :create, xhr: true, params: { :three_sixty_question => {:title => "", :question_type => ThreeSixty::Question::Type::TEXT}}
    end
    assert_response :success

    assert_equal ThreeSixty::Question::Type::TEXT, assigns(:question).question_type
    assert_nil assigns(:question).competency
    assert_equal programs(:org_primary), assigns(:question).organization
  end

  def test_create_oeq_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin
    
    assert_difference "ThreeSixty::Question.count", 1 do
      post :create, xhr: true, params: { :three_sixty_question => {:title => "new oeq title", :question_type => ThreeSixty::Question::Type::TEXT}}
    end

    assert_response :success

    assert_equal ThreeSixty::Question::Type::TEXT, assigns(:question).question_type
    assert_equal "new oeq title", assigns(:question).title
    assert_nil assigns(:question).competency
    assert_equal programs(:org_primary), assigns(:question).organization
  end

  def test_create_and_add_to_survey_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary
    
    post :create_and_add_to_survey
    assert_redirected_to new_session_path
  end

  def test_create_and_add_to_survey_non_admin_permission_denied
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :ram
    
    assert_permission_denied do    
      get :create_and_add_to_survey
    end
  end

  def test_create_and_add_to_survey_failure
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin
    
    assert_no_difference "ThreeSixty::Question.count" do
      post :create_and_add_to_survey, xhr: true, params: { :three_sixty_question => { :title => "", :survey_id => three_sixty_surveys(:survey_1).id }}
    end
    assert_response :success
    assert_equal "", assigns(:question).title
    assert_false assigns(:question).valid?
    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_nil assigns(:survey_question)

    three_sixty_surveys(:survey_1).publish!

    assert_record_not_found do
      assert_difference "ThreeSixty::Question.count", 1 do
        assert_no_difference "ThreeSixty::SurveyQuestion.count" do
          post :create_and_add_to_survey, xhr: true, params: { :three_sixty_question => {:title => "a new title", :question_type => ThreeSixty::Question::Type::TEXT, :survey_id => three_sixty_surveys(:survey_1).id}}
        end
      end
    end
  end

  def test_create_and_add_to_survey_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin
    
    assert_difference "ThreeSixty::Question.count", 1 do
      assert_difference "ThreeSixty::SurveyQuestion.count", 1 do
        post :create_and_add_to_survey, xhr: true, params: { :three_sixty_question => {:title => "new title", :question_type => ThreeSixty::Question::Type::TEXT, :survey_id => three_sixty_surveys(:survey_1).id}}
      end
    end

    assert_response :success

    assert_equal ThreeSixty::Question::Type::TEXT, assigns(:question).question_type
    assert_equal "new title", assigns(:question).title
    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal three_sixty_surveys(:survey_1), assigns(:survey_question).survey
    assert_equal "new title", assigns(:survey_question).question.title
  end

  def test_edit_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary
    
    get :edit, params: { :id => three_sixty_questions(:leadership_1).id}
    assert_redirected_to new_session_path
  end

  def test_edit_non_admin_permission_denied
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :ram
    
    assert_permission_denied do    
      get :edit, params: { :id => three_sixty_questions(:leadership_1).id}
    end
  end

  def test_edit_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin
    
    get :edit, xhr: true, params: { :id => three_sixty_questions(:leadership_1).id}
    assert_response :success

    assert_equal three_sixty_questions(:leadership_1), assigns(:question)
  end

  def test_edit_oeq_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin
    
    get :edit, xhr: true, params: { :id => three_sixty_questions(:oeq_1).id}
    assert_response :success

    assert_equal three_sixty_questions(:oeq_1), assigns(:question)
  end

  def test_update_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary
    
    get :update, params: { :id => three_sixty_questions(:leadership_1).id}
    assert_redirected_to new_session_path
  end

  def test_update_non_admin_permission_denied
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :ram
    
    assert_permission_denied do    
      get :update, params: { :id => programs(:org_primary).three_sixty_competencies.first.id}
    end
  end

  def test_update_failure
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin
    
    assert_no_difference "ThreeSixty::Question.count" do
      post :update, xhr: true, params: { :id => three_sixty_questions(:leadership_1).id, :three_sixty_question => {:title => "Do people blindly follow you?", :question_type => ThreeSixty::Question::Type::TEXT}}
    end
    assert_response :success

    assert_equal ThreeSixty::Question::Type::RATING, assigns(:question).question_type
    assert_equal "Do people blindly follow you?", assigns(:question).title
    assert_equal three_sixty_competencies(:leadership), assigns(:question).competency
    assert_equal ThreeSixty::Question::Type::RATING, three_sixty_questions(:leadership_1).question_type
    assert_equal "Are you a leader?", three_sixty_questions(:leadership_1).reload.title
  end

  def test_update_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin
    
    assert_no_difference "ThreeSixty::Question.count" do
      post :update, xhr: true, params: { :id => three_sixty_questions(:leadership_1).id, :three_sixty_question => {:title => "updated title", :question_type => ThreeSixty::Question::Type::TEXT}}
    end
    assert_response :success

    assert_equal ThreeSixty::Question::Type::RATING, assigns(:question).question_type
    assert_equal "updated title", assigns(:question).title
    assert_equal three_sixty_competencies(:leadership), assigns(:question).competency
    assert_equal "updated title", three_sixty_questions(:leadership_1).reload.title
    assert_equal ThreeSixty::Question::Type::RATING, three_sixty_questions(:leadership_1).question_type
  end

  def test_update_oeq_failure
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin
    
    assert_no_difference "ThreeSixty::Question.count" do
      post :update, xhr: true, params: { :id => three_sixty_questions(:oeq_1).id, :three_sixty_question => {:title => "", :question_type => ThreeSixty::Question::Type::RATING, :three_sixty_competency_id => programs(:org_primary).three_sixty_competencies.first.id}}
    end
    assert_response :success

    assert_equal ThreeSixty::Question::Type::TEXT, assigns(:question).question_type
    assert_equal "", assigns(:question).title
    assert_nil assigns(:question).competency
    assert_equal ThreeSixty::Question::Type::TEXT, three_sixty_questions(:oeq_1).question_type
    assert_equal "Things to keep doing", three_sixty_questions(:oeq_1).reload.title
  end

  def test_update_oeq_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin
    
    assert_no_difference "ThreeSixty::Question.count" do
      post :update, xhr: true, params: { :id => three_sixty_questions(:oeq_1).id, :three_sixty_question => {:title => "updated title"}}
    end
    assert_response :success

    assert_equal ThreeSixty::Question::Type::TEXT, assigns(:question).question_type
    assert_equal "updated title", assigns(:question).title
    assert_nil assigns(:question).competency
    assert_equal ThreeSixty::Question::Type::TEXT, three_sixty_questions(:oeq_1).question_type
    assert_equal "updated title", three_sixty_questions(:oeq_1).reload.title
  end

  def test_destroy_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary
    
    assert_no_difference "ThreeSixty::Question.count" do
      delete :destroy, xhr: true, params: { :id => three_sixty_questions(:leadership_1).id}
    end
  end

  def test_destroy_non_admin_permission_denied
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :ram
    
    assert_no_difference "ThreeSixty::Question.count" do
      assert_permission_denied do    
        delete :destroy, xhr: true, params: { :id => programs(:org_primary).three_sixty_competencies.first.id}
      end
    end
  end

  def test_destroy_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin
    
    assert_difference "ThreeSixty::Question.count", -1 do
      delete :destroy, xhr: true, params: { :id => three_sixty_questions(:leadership_1).id}
    end
    assert_response :success
  end

  def test_destroy_oeq_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin
    
    assert_difference "ThreeSixty::Question.count", -1 do
      delete :destroy, xhr: true, params: { :id => three_sixty_questions(:oeq_1).id}
    end
    assert_response :success
  end
end