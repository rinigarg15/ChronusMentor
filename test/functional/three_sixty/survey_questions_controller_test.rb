require_relative './../../test_helper.rb'

class ThreeSixty::SurveyQuestionsControllerTest < ActionController::TestCase

  def test_any_action_without_feature_permission_denied
    assert_false programs(:org_primary).has_feature?(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    assert_permission_denied do
      get :new, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_2)}
    end

    assert_permission_denied do
      post :create, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_2)}
    end

    assert_permission_denied do
      delete :destroy, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_2), :id => three_sixty_survey_questions(:three_sixty_survey_questions_5).id}
    end
  end

  def test_new_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    get :new, params: { :survey_id => three_sixty_surveys(:survey_2), :competency_id => three_sixty_survey_competencies(:three_sixty_survey_competencies_5).id}
    assert_redirected_to new_session_path
  end

  def test_new_non_admin_permission_denied
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_student

    assert_permission_denied do
      get :new, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_2), :competency_id => three_sixty_survey_competencies(:three_sixty_survey_competencies_5).id}
    end
  end

  def test_new_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    get :new, params: { :survey_id => three_sixty_surveys(:survey_2), :competency_id => three_sixty_survey_competencies(:three_sixty_survey_competencies_5).id}
    assert_response :success

    assert_equal three_sixty_surveys(:survey_2), assigns(:survey)
    assert_equal three_sixty_survey_competencies(:three_sixty_survey_competencies_5), assigns(:survey_competency)
    assert_equal_unordered [three_sixty_questions(:leadership_1), three_sixty_questions(:leadership_2)], assigns(:questions)
  end

  def test_create_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    
    assert_no_difference "ThreeSixty::SurveyQuestion.count" do
      post :create, params: { :survey_id => three_sixty_surveys(:survey_2).id, :competency_id => three_sixty_survey_competencies(:three_sixty_survey_competencies_5).id, :questions => [three_sixty_questions(:leadership_1).id, three_sixty_questions(:leadership_2).id]}
    end
    assert_redirected_to new_session_path
  end

  def test_create_non_admin_permission_denied
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_student

    assert_permission_denied do
      assert_no_difference "ThreeSixty::SurveyQuestion.count" do
        post :create, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_2).id, :competency_id => three_sixty_survey_competencies(:three_sixty_survey_competencies_5).id, :questions => [three_sixty_questions(:leadership_1).id, three_sixty_questions(:leadership_2).id]}
      end
    end
  end

  def test_create_failure
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    assert_no_difference "ThreeSixty::SurveyQuestion.count" do
      post :create, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_2).id, :competency_id => three_sixty_survey_competencies(:three_sixty_survey_competencies_5).id, :questions => [three_sixty_questions(:leadership_3).id]}
    end

    assert_equal three_sixty_surveys(:survey_2), assigns(:survey)
    assert_equal three_sixty_survey_competencies(:three_sixty_survey_competencies_5), assigns(:survey_competency)
  end

  def test_create_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    assert_false three_sixty_surveys(:survey_1).competencies.include?(three_sixty_competencies(:leadership))

    assert_difference "ThreeSixty::SurveyQuestion.count", 2 do
      post :create, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_2).id, :competency_id => three_sixty_survey_competencies(:three_sixty_survey_competencies_5).id, :questions => [three_sixty_questions(:leadership_1).id, three_sixty_questions(:leadership_2).id]}
    end

    assert_equal three_sixty_surveys(:survey_2), assigns(:survey)
    assert_equal three_sixty_survey_competencies(:three_sixty_survey_competencies_5), assigns(:survey_competency)
    assert_equal 2, assigns(:survey_questions).size
  end

  def test_create_oeq_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    assert_difference "ThreeSixty::SurveyQuestion.count", 1 do
      post :create, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_1).id, :question_id => three_sixty_questions(:oeq_3).id}
    end

    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_nil assigns(:survey_competency)
    assert_equal [], assigns(:available_oeqs)
    assert_equal three_sixty_questions(:oeq_3), assigns(:survey_question).question
  end

  def test_destroy_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    assert_no_difference "ThreeSixty::SurveyCompetency.count" do
      assert_no_difference "ThreeSixty::SurveyQuestion.count" do
        delete :destroy, params: { :survey_id => three_sixty_surveys(:survey_2).id, :id => three_sixty_survey_questions(:three_sixty_survey_questions_5).id}
      end
    end
    assert_redirected_to new_session_path
  end

  def test_destroy_non_admin_permission_denied
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_student

    assert_permission_denied do
      assert_no_difference "ThreeSixty::SurveyCompetency.count" do
        assert_no_difference "ThreeSixty::SurveyQuestion.count" do
          delete :destroy, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_2).id, :id => three_sixty_survey_questions(:three_sixty_survey_questions_5).id}
        end
      end
    end
  end

  def test_destroy_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    assert three_sixty_surveys(:survey_2).competencies.include?(three_sixty_competencies(:listening))

    assert_difference "ThreeSixty::SurveyCompetency.count", -1 do
      assert_difference "ThreeSixty::SurveyQuestion.count", -1 do
        delete :destroy, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_2).id, :id => three_sixty_survey_questions(:three_sixty_survey_questions_5).id}
      end
    end

    assert_equal three_sixty_surveys(:survey_2), assigns(:survey)
    assert_false three_sixty_surveys(:survey_2).competencies.include?(three_sixty_competencies(:listening))
    assert_equal_unordered [three_sixty_competencies(:listening), three_sixty_competencies(:delegating)], assigns(:available_competencies)
  end

  def test_destroy_oeq_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    assert_no_difference "ThreeSixty::SurveyCompetency.count" do
      assert_difference "ThreeSixty::SurveyQuestion.count", -1 do
        delete :destroy, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_1).id, :id => three_sixty_survey_questions(:three_sixty_survey_questions_3).id}
      end
    end

    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_nil assigns(:survey_competency)
    assert_equal_unordered [three_sixty_competencies(:leadership), three_sixty_competencies(:delegating)], assigns(:available_competencies)
    assert_equal_unordered [three_sixty_questions(:oeq_1), three_sixty_questions(:oeq_3)], assigns(:available_oeqs)
  end
end