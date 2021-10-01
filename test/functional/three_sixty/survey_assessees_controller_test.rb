require_relative './../../test_helper.rb'

class ThreeSixty::SurveyAssesseesControllerTest < ActionController::TestCase
  def test_any_action_without_feature_permission_denied
    assert_false programs(:org_primary).has_feature?(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    assert_permission_denied do
      post :create, params: { :survey_id => three_sixty_surveys(:survey_1)}
    end

    assert_permission_denied do
      get :add_reviewers, params: { :survey_id => three_sixty_surveys(:survey_1), :id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id}
    end

    assert_permission_denied do
      get :notify_reviewers, params: { :survey_id => three_sixty_surveys(:survey_1), :id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id}
    end

    assert_permission_denied do
      get :index
    end
  end

  def test_create_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    post :create, params: { :survey_id => three_sixty_surveys(:survey_1)}
    assert_redirected_to new_session_path
  end

  def test_create_non_admin_permission_denied
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_student

    assert_permission_denied do
      post :create, xhr: true, params: { :survey_id => three_sixty_surveys(:survey_1)}
    end
  end

  def test_published_destroy
    ThreeSixty::SurveyAssessee.expects(:get_es_results).with({:sort_param=>"title", :sort_order=>"asc", :page=>2, :per_page=>5, :search_params=>{:page=>2, :per_page=>5, :sort_field=>"title", :sort_order=>"asc"}, :filter=>{:organization_id=>1, :state=>"published", :id=>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]}, :includes_list=>[{:survey=>[:program]}, :assessee, {:reviewers=>:answers}]}).returns(ThreeSixty::SurveyAssessee.where(id: []).paginate(page: 2, per_page: 5).includes([{survey: [:program]}, :assessee, {reviewers: :answers}])).once
    ThreeSixty::SurveyAssessee.expects(:get_es_results).with({:sort_param=>"title", :sort_order=>"asc", :page=>1, :per_page=>5, :search_params=>{:page=>1, :per_page=>5, :sort_field=>"title", :sort_order=>"asc"}, :filter=>{:organization_id=>1, :state=>"published", :id=>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]}, :includes_list=>[{:survey=>[:program]}, :assessee, {:reviewers=>:answers}]}).returns(ThreeSixty::SurveyAssessee.where(id: [10, 11, 12, 13, 14]).paginate(page: 1, per_page: 5).includes([{survey: [:program]}, :assessee, {reviewers: :answers}])).once

    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin
    assert_difference "ThreeSixty::SurveyAssessee.count", -1 do
      delete :destroy_published, xhr: true, params: { :id => three_sixty_survey_assessees(:three_sixty_survey_assessees_15).id, :survey_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_15).survey.id, :from_dashboard => true, :page => 2}
    end
    assert_equal 1, assigns(:options)[:page]
    ThreeSixty::SurveyAssessee.expects(:get_es_results).with({:sort_param=>"title", :sort_order=>"asc", :page=>1, :per_page=>5, :search_params=>{:page=>1, :per_page=>5, :sort_field=>"title", :sort_order=>"asc"}, :filter=>{:organization_id=>1, :state=>"published", :id=>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]}, :includes_list=>[{:survey=>[:program]}, :assessee, {:reviewers=>:answers}]}).returns(ThreeSixty::SurveyAssessee.where(id: [10, 11, 12, 13]).paginate(page: 1, per_page: 5).includes([{survey: [:program]}, :assessee, {reviewers: :answers}])).once
    assert_difference "ThreeSixty::SurveyAssessee.count", -1 do
      delete :destroy_published, xhr: true, params: { :id => three_sixty_survey_assessees(:three_sixty_survey_assessees_14).id, :survey_id => three_sixty_survey_assessees(:three_sixty_survey_assessees_14).survey.id, :from_dashboard => true, :page => 1}
    end
    assert_equal 1, assigns(:options)[:page]
  end

  def test_add_reviewers_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    get :add_reviewers, params: { :survey_id => three_sixty_surveys(:survey_1), :id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id}
    assert_redirected_to new_session_path
  end

  def test_add_reviewers_non_owner
    three_sixty_surveys(:survey_1).publish!
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    assert_equal members(:f_student), three_sixty_survey_assessees(:three_sixty_survey_assessees_2).assessee
    current_organization_is :org_primary
    current_member_is :f_admin

    assert_permission_denied do
      get :add_reviewers, params: { :survey_id => three_sixty_surveys(:survey_1), :id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id}
    end
  end

  def test_add_reviewers_not_published
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    assert_equal members(:f_student), three_sixty_survey_assessees(:three_sixty_survey_assessees_2).assessee
    assert_false three_sixty_surveys(:survey_1).reload.published?

    current_organization_is :org_primary
    current_member_is :f_student

    assert_raise(ActiveRecord::RecordNotFound) do
      get :add_reviewers, params: { :survey_id => three_sixty_surveys(:survey_1), :id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id}
    end

    assert_nil assigns(:survey)
    assert_nil assigns(:survey_assessee)
  end

  def test_add_reviewers_survey_expired
    three_sixty_surveys(:survey_1).publish!
    ThreeSixty::SurveyPolicy.any_instance.stubs(:not_accessible?).returns(true)
    ThreeSixty::SurveyPolicy.any_instance.stubs(:error_message).returns("Text for test")

    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    assert_equal members(:f_student), three_sixty_survey_assessees(:three_sixty_survey_assessees_2).assessee

    current_organization_is :org_primary
    current_member_is :f_student

    get :add_reviewers, params: { :survey_id => three_sixty_surveys(:survey_1), :id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id}

    assert_redirected_to root_organization_path
    assert_equal "Text for test", flash[:error]
  end

  def test_add_reviewers_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    assert_equal members(:f_student), three_sixty_survey_assessees(:three_sixty_survey_assessees_2).assessee
    three_sixty_surveys(:survey_1).publish!

    current_organization_is :org_primary
    current_member_is :f_student

    get :add_reviewers, params: { :survey_id => three_sixty_surveys(:survey_1), :id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id}
    assert_false assigns(:back_link).present?
    assert_response :success

    assert_equal three_sixty_surveys(:survey_1), assigns(:survey)
    assert_equal three_sixty_survey_assessees(:three_sixty_survey_assessees_2), assigns(:survey_assessee)
    assert_equal 4, assigns(:survey_reviewer_groups).size
    assert_equal 4, assigns(:pending_survey_reviewers).size
    assert_equal 0, assigns(:invited_survey_reviewers).size
    assert_false assigns(:show_edit_survey_response)

    get :add_reviewers, params: { :survey_id => three_sixty_surveys(:survey_1), :id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :src => "email", :view => ThreeSixty::Survey::SURVEY_SHOW}
    assert_response :success
    assert_equal ({:label => assigns(:survey).title, :link => three_sixty_survey_path(assigns(:survey))}), assigns(:back_link)
    assert assigns(:show_edit_survey_response)

    get :add_reviewers, params: { :survey_id => three_sixty_surveys(:survey_1), :id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id, :src => "email", :view => ThreeSixty::Survey::MY_SURVEYS}
    assert_response :success
    assert_equal ({:label => "quick_links.program.three_sixty_surveys_v1".translate, :link => three_sixty_my_surveys_path}), assigns(:back_link)
    assert assigns(:show_edit_survey_response)
    assert_match(/You need to add at least 3 Peers, one Line Manager and 3 Direct Reports before proceeding/, @response.body.to_s)
  end

  def test_notify_reviewers_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    assert_no_emails do
      get :notify_reviewers, params: { :survey_id => three_sixty_surveys(:survey_1), :id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id}
    end
    assert_redirected_to new_session_path
  end

  def test_notify_reviewers_non_owner
    three_sixty_surveys(:survey_1).publish!
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    assert_equal members(:f_student), three_sixty_survey_assessees(:three_sixty_survey_assessees_2).assessee
    current_organization_is :org_primary
    current_member_is :f_admin

    assert_permission_denied do
      assert_no_emails do
        get :notify_reviewers, params: { :survey_id => three_sixty_surveys(:survey_1), :id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id}
      end
    end
  end

  def test_notify_reviewers_not_published
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    assert_equal members(:f_student), three_sixty_survey_assessees(:three_sixty_survey_assessees_2).assessee
    assert_false three_sixty_surveys(:survey_1).reload.published?

    current_organization_is :org_primary
    current_member_is :f_student

    assert_raise(ActiveRecord::RecordNotFound) do
      assert_no_emails do
        get :notify_reviewers, params: { :survey_id => three_sixty_surveys(:survey_1), :id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id}
      end
    end
  end

  def test_notify_reviewers_survey_expired
    three_sixty_surveys(:survey_1).publish!
    ThreeSixty::SurveyPolicy.any_instance.stubs(:not_accessible?).returns(true)
    ThreeSixty::SurveyPolicy.any_instance.stubs(:error_message).returns("Text for test")

    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    assert_equal members(:f_student), three_sixty_survey_assessees(:three_sixty_survey_assessees_2).assessee

    current_organization_is :org_primary
    current_member_is :f_student

    assert_no_emails do
      get :notify_reviewers, params: { :survey_id => three_sixty_surveys(:survey_1), :id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id}
    end

    assert_redirected_to root_organization_path
    assert_equal "Text for test", flash[:error]
  end

  def test_notify_reviewers_threshold_not_met
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    assert_equal members(:f_student), three_sixty_survey_assessees(:three_sixty_survey_assessees_2).assessee
    three_sixty_surveys(:survey_1).publish!

    current_organization_is :org_primary
    current_member_is :f_student
    survey = three_sixty_surveys(:survey_1)

    assert_false three_sixty_survey_assessees(:three_sixty_survey_assessees_2).threshold_met?
    get :notify_reviewers, params: { :survey_id => survey.reload, :id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id}
    assert_redirected_to add_reviewers_three_sixty_survey_assessee_path(survey, three_sixty_survey_assessees(:three_sixty_survey_assessees_2))
  end

  def test_notify_reviewers_success
    ThreeSixty::SurveyAssessee.any_instance.stubs(:threshold_met?).returns(true)
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    assert_equal members(:f_student), three_sixty_survey_assessees(:three_sixty_survey_assessees_2).assessee
    three_sixty_surveys(:survey_1).publish!

    current_organization_is :org_primary
    current_member_is :f_student
    survey = three_sixty_surveys(:survey_1)
    assert three_sixty_survey_assessees(:three_sixty_survey_assessees_2).threshold_met?

    assert_emails 5 do
      get :notify_reviewers, params: { :survey_id => survey, :id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id}
    end
    assert_redirected_to root_organization_path
    assert_nil flash[:error]
    assert_equal "The reviewers you have added will be notified shortly.", flash[:notice]
  end

  def test_notify_reviewers_admin_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    ThreeSixty::AddReviewerPolicy.any_instance.stubs(:admin_managing_survey?).returns(true)
    three_sixty_surveys(:survey_1).publish!

    current_organization_is :org_primary
    current_member_is :f_admin
    survey = three_sixty_surveys(:survey_1)
    assert_false three_sixty_survey_assessees(:three_sixty_survey_assessees_2).threshold_met?

    assert_emails 5 do
      get :notify_reviewers, params: { :survey_id => survey, :id => three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id}
    end
    assert_redirected_to root_organization_path
    assert_nil flash[:error]
    assert_equal "The reviewers you have added will be notified shortly.", flash[:notice]
  end

  def test_index_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    get :index

    assert_nil assigns(:survey_assessees)
    assert_nil assigns(:self_reviewers)

    assert_redirected_to new_session_path
  end

  def test_index_no_surveys
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary
    current_member_is :f_user

    get :index
    assert_response :success

    assert assigns(:survey_assessees).empty?
    assert assigns(:self_reviewers).empty?
  end

  def test_index_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_student
    get :index
    assert_response :success

    assert_equal [three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2)], assigns(:self_reviewers)[2]

    three_sixty_surveys(:survey_1).publish!
    get :index
    assert_response :success
    assert_no_match(/Add Reviewers/, @response.body)
    assert_equal [three_sixty_survey_assessees(:three_sixty_survey_assessees_2), three_sixty_survey_assessees(:three_sixty_survey_assessees_14)], assigns(:survey_assessees)
    assert_equal [three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2)], assigns(:self_reviewers)[three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id]

    three_sixty_surveys(:survey_1).update_attributes(:reviewers_addition_type => ThreeSixty::Survey::ReviewersAdditionType::ASSESSEE_ONLY)
    ThreeSixty::SurveyReviewer.any_instance.stubs(:answered?).returns(true)
    get :index
    assert_response :success
    assert_match(/Add Reviewers/, @response.body)

  end

  def test_index_success_program_level
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_user_is :f_student

    get :index
    assert_response :success
    assert assigns(:survey_assessees).empty?
    assert_equal [three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2)], assigns(:self_reviewers)[2]

    three_sixty_surveys(:survey_1).publish!

    get :index
    assert_response :success

    assert_equal [three_sixty_survey_assessees(:three_sixty_survey_assessees_2)], assigns(:survey_assessees)
    assert_equal [three_sixty_survey_reviewers(:three_sixty_survey_reviewers_2)], assigns(:self_reviewers)[three_sixty_survey_assessees(:three_sixty_survey_assessees_2).id]
  end
end