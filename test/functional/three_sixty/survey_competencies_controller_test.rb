require_relative './../../test_helper.rb'

class ThreeSixty::SurveyCompetenciesControllerTest < ActionController::TestCase

  def test_any_action_without_feature_permission_denied
    assert_false programs(:org_primary).has_feature?(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    assert_permission_denied do
      post :create, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_1).id}
    end

    assert_permission_denied do
      delete :destroy, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_1).id, :id => three_sixty_competencies(:listening).survey_competencies.first.id}
    end

    assert_permission_denied do
      put :reorder_questions, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_1).id, :id => three_sixty_competencies(:listening).survey_competencies.first.id}
    end
  end

  def test_create_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    assert_no_difference "ThreeSixty::SurveyCompetency.count" do
      assert_no_difference "ThreeSixty::SurveyQuestion.count" do
        post :create, params: { :survey_id => three_sixty_surveys(:survey_1).id, :competency_id => three_sixty_competencies(:leadership).id}
      end
    end
    assert_redirected_to new_session_path
  end

  def test_create_non_admin_permission_denied
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_student

    assert_permission_denied do
      assert_no_difference "ThreeSixty::SurveyCompetency.count" do
        assert_no_difference "ThreeSixty::SurveyQuestion.count" do
          post :create, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_1).id, :competency_id => three_sixty_competencies(:leadership).id}
        end
      end
    end
  end

  def test_create_failure
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    assert_no_difference "ThreeSixty::SurveyCompetency.count" do
      assert_no_difference "ThreeSixty::SurveyQuestion.count" do
        post :create, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_1).id, :competency_id => three_sixty_competencies(:listening).id}
      end
    end

    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal three_sixty_competencies(:listening), assigns(:competency)
  end

  def test_create_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    assert_false three_sixty_surveys(:survey_1).competencies.include?(three_sixty_competencies(:leadership))

    assert_difference "ThreeSixty::SurveyCompetency.count", 1 do
      assert_difference "ThreeSixty::SurveyQuestion.count", 3 do
        post :create, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_1).id, :competency_id => three_sixty_competencies(:leadership).id}
      end
    end

    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal three_sixty_competencies(:leadership), assigns(:competency)
    assert_equal three_sixty_surveys(:survey_1), assigns(:survey_competency).survey
    assert_equal three_sixty_competencies(:leadership), assigns(:survey_competency).competency
    assert_equal [three_sixty_competencies(:delegating)], assigns(:available_competencies)
    assert three_sixty_surveys(:survey_1).reload.competencies.include?(three_sixty_competencies(:leadership))
  end

  def test_destroy_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    assert_no_difference "ThreeSixty::SurveyCompetency.count" do
      assert_no_difference "ThreeSixty::SurveyQuestion.count" do
        delete :destroy, params: { :survey_id => three_sixty_surveys(:survey_1).id, :id => three_sixty_competencies(:listening).survey_competencies.first.id}
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
          delete :destroy, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_1).id, :id => three_sixty_competencies(:listening).survey_competencies.first.id}
        end
      end
    end
  end

  def test_destroy_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    assert three_sixty_surveys(:survey_1).competencies.include?(three_sixty_competencies(:listening))

    assert_difference "ThreeSixty::SurveyCompetency.count", -1 do
      assert_difference "ThreeSixty::SurveyQuestion.count", -1 do
        delete :destroy, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_1).id, :id => three_sixty_competencies(:listening).survey_competencies.first.id}
      end
    end

    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal three_sixty_competencies(:listening), assigns(:survey_competency).competency
    assert_equal_unordered [three_sixty_competencies(:listening), three_sixty_competencies(:leadership), three_sixty_competencies(:delegating)], assigns(:available_competencies)
    assert_false three_sixty_surveys(:survey_1).reload.competencies.include?(three_sixty_competencies(:listening))
  end

  def test_reorder_questions_not_logged_in
    ReorderService.any_instance.stubs(:reorder).at_most(0)
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    put :reorder_questions, params: { :survey_id => three_sixty_surveys(:survey_1).id, :id => three_sixty_competencies(:listening).survey_competencies.first.id, "new_order"=>["1"]}

    assert_redirected_to new_session_path
  end

  def test_reorder_questions_non_admin_permission_denied
    ReorderService.any_instance.stubs(:reorder).at_most(0)
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_student

    assert_permission_denied do
      put :reorder_questions, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_1).id, :id => three_sixty_competencies(:listening).survey_competencies.first.id, "new_order"=>["1"]}
    end
  end

  def test_reorder_questions_success
    ReorderService.any_instance.stubs(:reorder).with(["1"]).at_least(1)
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    put :reorder_questions, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_1).id, :id => three_sixty_competencies(:listening).survey_competencies.first.id, "new_order"=>["1"]}

    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal three_sixty_competencies(:listening), assigns(:survey_competency).competency
    assert_blank response.body
  end
end