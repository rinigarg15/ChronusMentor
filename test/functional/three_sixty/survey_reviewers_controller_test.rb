require_relative './../../test_helper.rb'

class ThreeSixty::SurveyReviewersControllerTest < ActionController::TestCase
  def test_any_action_without_feature_permission_denied
    assert_false programs(:org_primary).has_feature?(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    assert_permission_denied do
      get :show_reviewers, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :code => three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2).invitation_code}
    end

    assert_permission_denied do
      post :create, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id}
    end

    assert_permission_denied do
      get :edit, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :id => three_sixty_survey_reviewers(:survey_reviewer_7).id}
    end

    assert_permission_denied do
      post :update, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :id => three_sixty_survey_reviewers(:survey_reviewer_7).id}
    end

    assert_permission_denied do
      delete :destroy, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :id => three_sixty_survey_reviewers(:survey_reviewer_7).id}
    end

    assert_permission_denied do
      post :answer, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :code => three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2).invitation_code}
    end
  end

  def test_create_not_logged_in
    three_sixty_surveys(:survey_1).publish!
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    assert_no_difference "ThreeSixty::SurveyReviewer.count" do
      post :create, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id}
    end
    assert_redirected_to new_session_path
  end

  def test_create_not_published
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    assert_equal members(:f_student), three_sixty_survey_assessees(:three_sixty_survey_assessees_2).assessee
    assert_false three_sixty_surveys(:survey_1).reload.published?
    current_organization_is :org_primary
    current_member_is :f_student

    assert_raise(ActiveRecord::RecordNotFound) do
      assert_no_difference "ThreeSixty::SurveyReviewer.count" do
        post :create, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :three_sixty_survey_reviewer => {:name => "some name", :email => "vaild@example.com", :three_sixty_survey_reviewer_group_id => three_sixty_survey_reviewer_groups(:three_sixty_survey_reviewer_groups_2).id}}
      end
    end

    assert_nil assigns(:survey)
  end

  def test_create_survey_expired
    three_sixty_surveys(:survey_1).publish!
    ThreeSixty::SurveyPolicy.any_instance.stubs(:not_accessible?).returns(true)
    ThreeSixty::SurveyPolicy.any_instance.stubs(:error_message).returns("Text for test")

    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    assert_equal members(:f_student), three_sixty_survey_assessees(:three_sixty_survey_assessees_2).assessee

    current_organization_is :org_primary
    current_member_is :f_student

    assert_no_difference "ThreeSixty::SurveyReviewer.count" do
      post :create, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id}
    end
    
    assert_redirected_to about_path
    assert_equal "Text for test", flash[:error]

    assert_no_difference "ThreeSixty::SurveyReviewer.count" do
      post :create, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id}
    end
    assert_template "three_sixty/surveys/_policy_warning"
  end

  def test_create_failure
    ThreeSixty::AddReviewerPolicy.any_instance.stubs(:can_add_reviewers?).returns(true)
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    assert_equal members(:f_student), three_sixty_survey_assessees(:three_sixty_survey_assessees_2).assessee
    three_sixty_surveys(:survey_1).publish!
    current_organization_is :org_primary
    current_member_is :f_mentor

    assert_no_difference "ThreeSixty::SurveyReviewer.count" do
      post :create, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :three_sixty_survey_reviewer => {:email => "vaild@example.com", :three_sixty_survey_reviewer_group_id => three_sixty_survey_reviewer_groups(:three_sixty_survey_reviewer_groups_2).id}}
    end

    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal three_sixty_survey_assessees(:three_sixty_survey_assessees_2), assigns(:survey_assessee)
    assert_equal 4, assigns(:survey_reviewer_groups).size
    assert assigns(:survey_reviewer).errors.present?
  end

  def test_create_cannot_add_reviewers
    ThreeSixty::AddReviewerPolicy.any_instance.stubs(:can_add_reviewers?).returns(false)
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    assert_equal members(:f_student), three_sixty_survey_assessees(:three_sixty_survey_assessees_2).assessee
    three_sixty_surveys(:survey_1).publish!
    current_organization_is :org_primary
    current_member_is :f_mentor

    assert_permission_denied do
      assert_no_difference "ThreeSixty::SurveyReviewer.count" do
        post :create, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id}
      end
    end
  end

  def test_create_success
    ThreeSixty::AddReviewerPolicy.any_instance.stubs(:can_add_reviewers?).returns(true)
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    assert_equal members(:f_student), three_sixty_survey_assessees(:three_sixty_survey_assessees_2).assessee
    three_sixty_surveys(:survey_1).publish!
    current_organization_is :org_primary
    current_member_is :f_mentor

    assert_difference "ThreeSixty::SurveyReviewer.count", 1 do
      post :create, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :three_sixty_survey_reviewer => {:name => "some name", :email => "vaild@example.com", :three_sixty_survey_reviewer_group_id => three_sixty_survey_reviewer_groups(:three_sixty_survey_reviewer_groups_2).id}}
    end

    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal three_sixty_survey_assessees(:three_sixty_survey_assessees_2), assigns(:survey_assessee)
    assert_equal 4, assigns(:survey_reviewer_groups).size
  end

  def test_edit_not_logged_in
    three_sixty_surveys(:survey_1).publish!
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    get :edit, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :id => three_sixty_survey_reviewers(:survey_reviewer_7).id}
    assert_redirected_to new_session_path
  end

  def test_edit_cannot_update_reviewer
    ThreeSixty::AddReviewerPolicy.any_instance.stubs(:can_update_reviewer?).returns(false)
    three_sixty_surveys(:survey_1).publish!
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    assert_equal members(:f_student), three_sixty_survey_assessees(:three_sixty_survey_assessees_2).assessee
    current_organization_is :org_primary
    current_member_is :f_student

    assert_permission_denied do
      get :edit, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :id => three_sixty_survey_reviewers(:survey_reviewer_7).id}
    end
  end

  def test_edit_not_published
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    assert_equal members(:f_student), three_sixty_survey_assessees(:three_sixty_survey_assessees_2).assessee
    assert_false three_sixty_surveys(:survey_1).reload.published?
    current_organization_is :org_primary
    current_member_is :f_student

    assert_raise(ActiveRecord::RecordNotFound) do
      get :edit, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :id => three_sixty_survey_reviewers(:survey_reviewer_7).id}
    end

    assert_nil assigns(:survey)
  end

  def test_edit_survey_expired
    three_sixty_surveys(:survey_1).publish!
    ThreeSixty::SurveyPolicy.any_instance.stubs(:not_accessible?).returns(true)
    ThreeSixty::SurveyPolicy.any_instance.stubs(:error_message).returns("Text for test")

    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    assert_equal members(:f_student), three_sixty_survey_assessees(:three_sixty_survey_assessees_2).assessee
    current_organization_is :org_primary
    current_member_is :f_student
    
    get :edit, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :id => three_sixty_survey_reviewers(:survey_reviewer_7).id}
    assert_redirected_to about_path
    assert_equal "Text for test", flash[:error]

    get :edit, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :id => three_sixty_survey_reviewers(:survey_reviewer_7).id}
    assert_template "three_sixty/surveys/_policy_warning"
  end

  def test_edit_success
    ThreeSixty::AddReviewerPolicy.any_instance.stubs(:can_update_reviewer?).returns(true)
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    assert_equal members(:f_student), three_sixty_survey_assessees(:three_sixty_survey_assessees_2).assessee
    three_sixty_surveys(:survey_1).publish!
    current_organization_is :org_primary
    current_member_is :f_student

    get :edit, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :id => three_sixty_survey_reviewers(:survey_reviewer_7).id}

    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal three_sixty_survey_assessees(:three_sixty_survey_assessees_2), assigns(:survey_assessee)
    assert_equal three_sixty_survey_reviewers(:survey_reviewer_7), assigns(:survey_reviewer)
    assert_equal 4, assigns(:survey_reviewer_groups).size
  end

  def test_update_not_logged_in
    three_sixty_surveys(:survey_1).publish!
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    post :update, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :id => three_sixty_survey_reviewers(:survey_reviewer_7).id}
    assert_redirected_to new_session_path
  end

  def test_update_cannot_update_reviewer
    ThreeSixty::AddReviewerPolicy.any_instance.stubs(:can_update_reviewer?).returns(false)
    three_sixty_surveys(:survey_1).publish!
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    assert_equal members(:f_student), three_sixty_survey_assessees(:three_sixty_survey_assessees_2).assessee
    current_organization_is :org_primary
    current_member_is :f_admin

    assert_permission_denied do
      post :update, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :id => three_sixty_survey_reviewers(:survey_reviewer_7).id}
    end
  end

  def test_update_not_published
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    assert_equal members(:f_student), three_sixty_survey_assessees(:three_sixty_survey_assessees_2).assessee
    assert_false three_sixty_surveys(:survey_1).reload.published?
    current_organization_is :org_primary
    current_member_is :f_student

    assert_raise(ActiveRecord::RecordNotFound) do
      post :update, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :id => three_sixty_survey_reviewers(:survey_reviewer_7).id}
    end

    assert_nil assigns(:survey)
  end

  def test_update_survey_expired
    three_sixty_surveys(:survey_1).publish!
    ThreeSixty::SurveyPolicy.any_instance.stubs(:not_accessible?).returns(true)
    ThreeSixty::SurveyPolicy.any_instance.stubs(:error_message).returns("Text for test")

    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    assert_equal members(:f_student), three_sixty_survey_assessees(:three_sixty_survey_assessees_2).assessee
    current_organization_is :org_primary
    current_member_is :f_student
    
    post :update, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :id => three_sixty_survey_reviewers(:survey_reviewer_7).id, :three_sixty_survey_reviewer => {:name => "some name", :email => "vaild@example.com", :three_sixty_survey_reviewer_group_id => three_sixty_survey_reviewer_groups(:three_sixty_survey_reviewer_groups_2).id}}
    assert_redirected_to about_path
    assert_equal "Text for test", flash[:error]

    post :update, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :id => three_sixty_survey_reviewers(:survey_reviewer_7).id, :three_sixty_survey_reviewer => {:name => "some name", :email => "vaild@example.com", :three_sixty_survey_reviewer_group_id => three_sixty_survey_reviewer_groups(:three_sixty_survey_reviewer_groups_2).id}}
    assert_false assigns(:survey_reviewer).name == "some name"
    assert_template "three_sixty/surveys/_policy_warning"
  end

  def test_update_failure
    ThreeSixty::AddReviewerPolicy.any_instance.stubs(:can_update_reviewer?).returns(true)
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    assert_equal members(:f_student), three_sixty_survey_assessees(:three_sixty_survey_assessees_2).assessee
    three_sixty_surveys(:survey_1).publish!
    current_organization_is :org_primary
    current_member_is :f_student

    post :update, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :id => three_sixty_survey_reviewers(:survey_reviewer_7).id, :three_sixty_survey_reviewer => {:name => "", :email => "vaild@example.com", :three_sixty_survey_reviewer_group_id => three_sixty_survey_reviewer_groups(:three_sixty_survey_reviewer_groups_2).id}}

    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal three_sixty_survey_assessees(:three_sixty_survey_assessees_2), assigns(:survey_assessee)
    assert assigns(:survey_reviewer).errors.present?
    assert_equal 4, assigns(:survey_reviewer_groups).size
  end

  def test_update_success
    ThreeSixty::AddReviewerPolicy.any_instance.stubs(:can_update_reviewer?).returns(true)
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    assert_equal members(:f_student), three_sixty_survey_assessees(:three_sixty_survey_assessees_2).assessee
    three_sixty_surveys(:survey_1).publish!
    current_organization_is :org_primary
    current_member_is :f_student

    post :update, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :id => three_sixty_survey_reviewers(:survey_reviewer_7).id, :three_sixty_survey_reviewer => {:name => "some name", :email => "vaild@example.com", :three_sixty_survey_reviewer_group_id => three_sixty_survey_reviewer_groups(:three_sixty_survey_reviewer_groups_2).id}}

    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal three_sixty_survey_assessees(:three_sixty_survey_assessees_2), assigns(:survey_assessee)
    assert_equal "some name", assigns(:survey_reviewer).name
    assert_equal 4, assigns(:survey_reviewer_groups).size
  end

  def test_destroy_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    three_sixty_surveys(:survey_1).publish!
    current_organization_is :org_primary

    assert_no_difference "ThreeSixty::SurveyReviewer.count" do
      delete :destroy, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :id => three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2).id}
    end
    assert_redirected_to new_session_path
  end

  def test_destroy_non_owner
    ThreeSixty::AddReviewerPolicy.any_instance.stubs(:can_update_reviewer?).returns(false)
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    assert_equal members(:f_student), three_sixty_survey_assessees(:three_sixty_survey_assessees_2).assessee
    three_sixty_surveys(:survey_1).publish!
    current_organization_is :org_primary
    current_member_is :f_admin

    assert_permission_denied do
      assert_no_difference "ThreeSixty::SurveyReviewer.count" do
        delete :destroy, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :id => three_sixty_survey_reviewers(:survey_reviewer_7).id}
      end
    end
  end

  def test_destroy_not_published
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    assert_equal members(:f_student), three_sixty_survey_assessees(:three_sixty_survey_assessees_2).assessee
    assert_false three_sixty_surveys(:survey_1).reload.published?
    current_organization_is :org_primary
    current_member_is :f_student

    assert_raise(ActiveRecord::RecordNotFound) do
      assert_no_difference "ThreeSixty::SurveyReviewer.count" do
        delete :destroy, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :id => three_sixty_survey_reviewers(:survey_reviewer_7).id}
      end
    end

    assert_nil assigns(:survey)
  end

  def test_destroy_survey_expired
    three_sixty_surveys(:survey_1).publish!
    ThreeSixty::SurveyPolicy.any_instance.stubs(:not_accessible?).returns(true)
    ThreeSixty::SurveyPolicy.any_instance.stubs(:error_message).returns("Text for test")

    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    assert_equal members(:f_student), three_sixty_survey_assessees(:three_sixty_survey_assessees_2).assessee

    current_organization_is :org_primary
    current_member_is :f_student

    assert_no_difference "ThreeSixty::SurveyReviewer.count" do
      delete :destroy, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :id => three_sixty_survey_reviewers(:survey_reviewer_7).id}
    end
    
    assert_redirected_to about_path
    assert_equal "Text for test", flash[:error]

    assert_no_difference "ThreeSixty::SurveyReviewer.count" do
      delete :destroy, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :id => three_sixty_survey_reviewers(:survey_reviewer_7).id}
    end
    assert_template "three_sixty/surveys/_policy_warning"
  end

  def test_destroy_success
    ThreeSixty::AddReviewerPolicy.any_instance.stubs(:can_update_reviewer?).returns(true)
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    assert_equal members(:f_student), three_sixty_survey_assessees(:three_sixty_survey_assessees_2).assessee
    three_sixty_surveys(:survey_1).publish!
    current_organization_is :org_primary
    current_member_is :f_student

    assert_difference "ThreeSixty::SurveyReviewer.count", -1 do
      delete :destroy, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :id => three_sixty_survey_reviewers(:survey_reviewer_7).id}
    end

    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal three_sixty_survey_assessees(:three_sixty_survey_assessees_2), assigns(:survey_assessee)
  end

  def test_show_invalid_code
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    three_sixty_surveys(:survey_1).publish!
    current_organization_is :org_primary

    assert_raise(NoMethodError) do
      get :show_reviewers, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :id => three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2).id}
    end

    assert_raise(NoMethodError) do
      get :show_reviewers, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :code => 'thisIsNotAValidCode'}
    end
  end

  def test_show_survey_expired
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    three_sixty_surveys(:survey_1).publish!
    ThreeSixty::SurveyPolicy.any_instance.stubs(:not_accessible?).returns(true)
    ThreeSixty::SurveyPolicy.any_instance.stubs(:error_message).returns("Text for test")
    current_organization_is :org_primary
    current_member_is :f_student

    get :show_reviewers, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :code => three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2).invitation_code}
    assert_redirected_to about_path
    assert_equal "Text for test", flash[:error]

    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal three_sixty_survey_assessees(:three_sixty_survey_assessees_2), assigns(:survey_assessee)
    assert_equal three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2), assigns(:survey_reviewer)
  end

  def test_show_for_assessee_redirect_if_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    three_sixty_surveys(:survey_1).publish!
    current_organization_is :org_primary

    get :show_reviewers, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :code => three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2).invitation_code}
    assert_redirected_to new_session_path

    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal three_sixty_survey_assessees(:three_sixty_survey_assessees_2), assigns(:survey_assessee)
    assert_equal three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2), assigns(:survey_reviewer)
    assert_nil assigns(:survey_competencies)
    assert_nil assigns(:survey_oeqs)
  end

  def test_show_for_assessee_permission_denied_if_wrong_member
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    three_sixty_surveys(:survey_1).publish!
    current_organization_is :org_primary
    current_member_is :f_admin

    assert_permission_denied do
      get :show_reviewers, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :code => three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2).invitation_code}
    end

    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal three_sixty_survey_assessees(:three_sixty_survey_assessees_2), assigns(:survey_assessee)
    assert_equal three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2), assigns(:survey_reviewer)
    assert_nil assigns(:survey_competencies)
    assert_nil assigns(:survey_oeqs)
  end

  def test_show_for_assessee_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    three_sixty_surveys(:survey_1).publish!
    current_organization_is :org_primary
    current_member_is :f_student

    get :show_reviewers, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :code => three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2).invitation_code, :src => 'email'}
    assert_nil assigns(:back_link)
    assert assigns(:is_for_self)
    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal three_sixty_survey_assessees(:three_sixty_survey_assessees_2), assigns(:survey_assessee)
    assert_equal three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2), assigns(:survey_reviewer)
    assert_equal three_sixty_surveys(:survey_1).survey_competencies, assigns(:survey_competencies)
    assert_equal three_sixty_surveys(:survey_1).survey_oeqs, assigns(:survey_oeqs)
    get :show_reviewers, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :code => three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2).invitation_code, :src => 'email', :view => ThreeSixty::Survey::MY_SURVEYS}
    assert_equal ({:label => "quick_links.program.three_sixty_surveys_v1".translate, :link => three_sixty_my_surveys_path}), assigns(:back_link)
    assert_select "h3", :text => "Open-ended Questions", :count => 1

    three_sixty_surveys(:survey_1).survey_oeqs.destroy_all
    get :show_reviewers, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :code => three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2).invitation_code, :src => 'email', :view => ThreeSixty::Survey::MY_SURVEYS}
    assert_equal [], assigns(:survey_oeqs)
    assert_select "h3", :text => "Open-ended Questions", :count => 0
  end

  def test_show_for_assessee_already_answered_non_logged_in_user
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    reviewer = three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2)
    assessee = three_sixty_survey_assessees(:three_sixty_survey_assessees_2)
    survey = three_sixty_surveys(:survey_1)
    survey.publish!

    ThreeSixty::SurveyReviewer.any_instance.stubs(:answered?).returns(true)
    current_organization_is :org_primary

    get :show_reviewers, params: { :survey_id => survey, :assessee_id => assessee.id, :code => reviewer.invitation_code}
    assert_redirected_to new_session_path

    assert_equal survey, assigns(:survey)
    assert_equal assessee, assigns(:survey_assessee)
    assert_equal reviewer, assigns(:survey_reviewer)
    assert_nil assigns(:survey_competencies)
    assert_nil assigns(:survey_oeqs)
  end

  def test_show_for_assessee_already_answered_logged_in_user
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    reviewer = three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2)
    assessee = three_sixty_survey_assessees(:three_sixty_survey_assessees_2)
    survey = three_sixty_surveys(:survey_1)
    survey.publish!

    ThreeSixty::SurveyReviewer.any_instance.stubs(:answered?).returns(true)
    current_member_is :f_student
    get :show_reviewers, params: { :survey_id => survey, :assessee_id => assessee.id, :code => reviewer.invitation_code, :src => 'email'}
    assert_redirected_to add_reviewers_three_sixty_survey_assessee_path(survey, assessee, :src => "email")
    assert assigns(:is_for_self)
    assert_equal survey, assigns(:survey)
    assert_equal assessee, assigns(:survey_assessee)
    assert_equal reviewer, assigns(:survey_reviewer)
    assert_nil assigns(:survey_competencies)
    assert_nil assigns(:survey_oeqs)

    survey.update_attributes(:reviewers_addition_type => ThreeSixty::Survey::ReviewersAdditionType::ADMIN_ONLY)
    get :show_reviewers, params: { :survey_id => survey, :assessee_id => assessee.id, :code => reviewer.invitation_code, :src => 'email'}
    assert_response :success
  end

  def test_show_for_reviewer_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    three_sixty_surveys(:survey_1).publish!
    current_organization_is :org_primary
    
    get :show_reviewers, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :code => three_sixty_survey_reviewers(:survey_reviewer_7).invitation_code, :src => 'email'}
    
    assert_false assigns(:is_for_self)
    assert assigns(:no_tabs)
    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal three_sixty_survey_assessees(:three_sixty_survey_assessees_2), assigns(:survey_assessee)
    assert_equal three_sixty_survey_reviewers(:survey_reviewer_7), assigns(:survey_reviewer)
    assert_equal three_sixty_surveys(:survey_1).survey_competencies, assigns(:survey_competencies)
    assert_equal three_sixty_surveys(:survey_1).survey_oeqs, assigns(:survey_oeqs)
  end

  def test_answer_invalid_code
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    three_sixty_surveys(:survey_1).publish!
    current_organization_is :org_primary

    assert_raise(NoMethodError) do
      post :answer, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :id => three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2).id}
    end

    assert_raise(NoMethodError) do
      post :answer, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :code => 'thisIsNotAValidCode'}
    end
  end

  def test_answer_survey_expired
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    three_sixty_surveys(:survey_1).publish!
    ThreeSixty::SurveyPolicy.any_instance.stubs(:not_accessible?).returns(true)
    ThreeSixty::SurveyPolicy.any_instance.stubs(:error_message).returns("Text for test")
    current_organization_is :org_primary
    current_member_is :f_student

    post :answer, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :code => three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2).invitation_code}
    assert_redirected_to about_path
    assert_equal "Text for test", flash[:error]

    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal three_sixty_survey_assessees(:three_sixty_survey_assessees_2), assigns(:survey_assessee)
    assert_equal three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2), assigns(:survey_reviewer)
  end

  def test_answer_for_assessee_redirect_if_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    three_sixty_surveys(:survey_1).publish!
    current_organization_is :org_primary

    post :answer, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :code => three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2).invitation_code}
    assert_redirected_to new_session_path

    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal three_sixty_survey_assessees(:three_sixty_survey_assessees_2), assigns(:survey_assessee)
    assert_equal three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2), assigns(:survey_reviewer)
  end

  def test_answer_for_assessee_permission_denied_if_wrong_member
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    three_sixty_surveys(:survey_1).publish!
    current_organization_is :org_primary
    current_member_is :f_admin

    assert_permission_denied do
      post :answer, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :code => three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2).invitation_code}
    end

    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal three_sixty_survey_assessees(:three_sixty_survey_assessees_2), assigns(:survey_assessee)
    assert_equal three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2), assigns(:survey_reviewer)
  end

  def test_answer_for_assessee_success_no_answers
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    three_sixty_surveys(:survey_1).publish!
    current_organization_is :org_primary
    current_member_is :f_student

    assert_no_difference "ThreeSixty::SurveyAnswer.count" do
      post :answer, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :code => three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2).invitation_code}
    end
    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal three_sixty_survey_assessees(:three_sixty_survey_assessees_2), assigns(:survey_assessee)
    assert_equal three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2), assigns(:survey_reviewer)
  end

  def test_answer_update_for_assessee_reviewer
    ThreeSixty::SurveyAnswer.destroy_all
    survey = three_sixty_surveys(:survey_1)
    reviewer = three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2)
    ThreeSixty::SurveyReviewer.any_instance.stubs(:answered?).returns(true)
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    three_sixty_surveys(:survey_1).publish!
    assert_false three_sixty_surveys(:survey_1).survey_oeqs.first.answers.present?
    current_organization_is :org_primary
    current_member_is :f_student

    assert_difference "ThreeSixty::SurveyAnswer.count", 3 do
      post :answer, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :code => three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2).invitation_code, :three_sixty_survey_answers => { "#{three_sixty_survey_questions(:three_sixty_survey_questions_1).id}" => "1", "#{three_sixty_survey_questions(:three_sixty_survey_questions_2).id}" => "A text answer", "#{three_sixty_survey_questions(:three_sixty_survey_questions_3).id}" => "An Oeq answer"}}
    end
    assert_redirected_to add_reviewers_three_sixty_survey_assessee_path(three_sixty_surveys(:survey_1), three_sixty_survey_assessees(:three_sixty_survey_assessees_2))
    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal three_sixty_survey_assessees(:three_sixty_survey_assessees_2), assigns(:survey_assessee)
    assert_equal three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2), assigns(:survey_reviewer)
    assert_equal ThreeSixty::Survey::ReviewersAdditionType::ASSESSEE_ONLY, three_sixty_surveys(:survey_1).reviewers_addition_type
    assert three_sixty_surveys(:survey_1).survey_oeqs.first.answers.present?

    assert_difference "ThreeSixty::SurveyAnswer.count", -2 do
      post :answer, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :code => three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2).invitation_code, :three_sixty_survey_answers => { "#{three_sixty_survey_questions(:three_sixty_survey_questions_1).id}" => "5", "#{three_sixty_survey_questions(:three_sixty_survey_questions_2).id}" => "", "#{three_sixty_survey_questions(:three_sixty_survey_questions_3).id}" => ""}}
    end
    assert_redirected_to add_reviewers_three_sixty_survey_assessee_path(three_sixty_surveys(:survey_1), three_sixty_survey_assessees(:three_sixty_survey_assessees_2))
    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal three_sixty_survey_assessees(:three_sixty_survey_assessees_2), assigns(:survey_assessee)
    assert_equal three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2), assigns(:survey_reviewer)
    assert_false three_sixty_surveys(:survey_1).survey_oeqs.first.answers.present?
  end

  def test_answer_for_reviewer_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    three_sixty_surveys(:survey_1).publish!
    current_organization_is :org_primary
    
    post :answer, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :code => three_sixty_survey_reviewers(:survey_reviewer_7).invitation_code}
    
    assert assigns(:no_tabs)
    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal three_sixty_survey_assessees(:three_sixty_survey_assessees_2), assigns(:survey_assessee)
    assert_equal three_sixty_survey_reviewers(:survey_reviewer_7), assigns(:survey_reviewer)
    assert_redirected_to about_path
    assert_equal "Thank you for taking part in student example's survey", flash[:notice]
  end

  def test_answer_update_name_failure
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    three_sixty_surveys(:survey_1).publish!
    current_organization_is :org_primary
    
    post :answer, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :code => three_sixty_survey_reviewers(:survey_reviewer_7).invitation_code, :three_sixty_survey_reviewer => { :name => "" }}
    
    assert assigns(:no_tabs)
    assert_template "three_sixty/survey_reviewers/show_reviewers"
    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal three_sixty_survey_assessees(:three_sixty_survey_assessees_2), assigns(:survey_assessee)
    assert_equal three_sixty_survey_reviewers(:survey_reviewer_7), assigns(:survey_reviewer)
    assert_equal three_sixty_surveys(:survey_1).survey_competencies, assigns(:survey_competencies)
    assert_equal three_sixty_surveys(:survey_1).survey_oeqs, assigns(:survey_oeqs)
    assert_false assigns(:survey_reviewer).valid?
    assert_equal "The name field cannot be empty", flash[:error]
    assert three_sixty_survey_reviewers(:survey_reviewer_7).reload.name.present?
  end

  def test_answer_update_name_no_update_for_self
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    three_sixty_surveys(:survey_1).publish!
    current_organization_is :org_primary
    current_member_is :f_student
    survey = three_sixty_surveys(:survey_1).update_attributes(:reviewers_addition_type => ThreeSixty::Survey::ReviewersAdditionType::ADMIN_ONLY)
    post :answer, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :code => three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2).invitation_code, :three_sixty_survey_reviewer => { :name => "A new name" }}
    assert_redirected_to root_path
    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal three_sixty_survey_assessees(:three_sixty_survey_assessees_2), assigns(:survey_assessee)
    assert_equal three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2), assigns(:survey_reviewer)
    assert_false three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2).reload.name == "A new name"
  end

  def test_answer_update_name_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    three_sixty_surveys(:survey_1).publish!
    current_organization_is :org_primary
    
    post :answer, params: { :survey_id => three_sixty_surveys(:survey_1), :assessee_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :code => three_sixty_survey_reviewers(:survey_reviewer_7).invitation_code, :three_sixty_survey_reviewer => { :name => "A new name" }}
    
    assert assigns(:no_tabs)
    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal three_sixty_survey_assessees(:three_sixty_survey_assessees_2), assigns(:survey_assessee)
    assert_equal three_sixty_survey_reviewers(:survey_reviewer_7), assigns(:survey_reviewer)
    assert_equal "A new name", three_sixty_survey_reviewers(:survey_reviewer_7).reload.name
    assert_redirected_to about_path
    assert_equal "Thank you for taking part in student example's survey", flash[:notice]
  end
end