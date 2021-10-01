require_relative './../../test_helper.rb'

class ThreeSixty::CompetenciesControllerTest < ActionController::TestCase
  def test_any_action_without_feature_permission_denied
    assert_false programs(:org_primary).has_feature?(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    assert_permission_denied do
      get :index
    end

    assert_permission_denied do
      get :new
    end

    assert_permission_denied do
      post :create
    end

    assert_permission_denied do
      get :edit, params: { :id => three_sixty_competencies(:leadership).id}
    end

    assert_permission_denied do
      put :update, params: { :id => three_sixty_competencies(:leadership).id}
    end

    assert_permission_denied do
      delete :destroy, params: { :id => three_sixty_competencies(:leadership).id}
    end
  end

  def test_index_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    get :index
    assert_redirected_to new_session_path
  end

  def test_index_non_admin_permission_denied
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_student

    assert_permission_denied do
      get :index
    end
  end

  def test_index_success
    competency_1 = three_sixty_competencies(:leadership)
    competency = programs(:org_primary).three_sixty_competencies.create!(:title => 'competency without questions')
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    get :index
    assert_response :success

    assert_equal programs(:org_primary).three_sixty_competencies, assigns(:competencies)
    assert_equal programs(:org_primary).three_sixty_oeqs, assigns(:open_ended_questions)
    assert_equal ThreeSixty::CommonController::Tab::COMPETENCIES, assigns(:active_tab)
    assert assigns(:show_actions)
    assert_select "a.btn.btn-primary.remote-popup-link"
    assert_select "div#three_sixty_competency_#{competency.id}"
    assert_select "div.col-md-2"
    assert_select "div#three_sixty_competency_#{competency_1.id}" do
      assert_select "big#competency_heading_title_#{competency_1.id}"
      assert_select "div#competency_heading_for_listing_#{competency_1.id}" do
        assert_select "a", :count => 2
      end
    end
    assert_select "div#three_sixty_oeqs" do
      assert_select "h5", :text => /Open-ended Questions/
      assert_select "div#open_ended_questions_container" do
        assert_select "div.well.cjs-alt-color-actions.cjs_three_sixty_parent", :count => 3
      end
    end
    assert_select "div#add_new_three_sixty_competency_container_#{competency_1.id}"
  end

  def test_index_success_for_program_admin
    competency_1 = three_sixty_competencies(:leadership)
    competency = programs(:org_primary).three_sixty_competencies.create!(:title => 'competency without questions')
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_user_is :ram

    get :index
    assert_response :success

    assert_equal programs(:org_primary).three_sixty_competencies, assigns(:competencies)
    assert_equal ThreeSixty::CommonController::Tab::COMPETENCIES, assigns(:active_tab)
    assert_false assigns(:show_actions)
    assert_no_select "a.btn.btn-primary.remote-popup-link"
    assert_no_select "div#three_sixty_competency_#{competency.id}"

    assert_select "div#three_sixty_competency_#{competency_1.id}" do
      assert_select "big#competency_heading_title_#{competency_1.id}"
      assert_select "div#competency_heading_for_listing_#{competency_1.id}" do
        assert_select "a", :count => 0
      end
    end
    assert_no_select "div#add_new_three_sixty_competency_container_#{competency_1.id}"
  end

  def test_new_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    get :new
    assert_redirected_to new_session_path
  end

  def test_new_non_admin_permission_denied
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :ram

    assert_permission_denied do
      get :new
    end
  end

  def test_new_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    get :new, xhr: true
    assert_response :success

    assert_equal programs(:org_primary), assigns(:competency).organization
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

    assert_no_difference "ThreeSixty::Competency.count" do
      post :create, xhr: true, params: { :three_sixty_competency => {:description => "no title"}}
    end
    assert_response :success

    assert_equal programs(:org_primary), assigns(:competency).organization
    assert_equal "no title", assigns(:competency).description
    assert_nil assigns(:competency).title
    assert_false assigns(:competency).valid?
  end

  def test_create_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    assert_difference "ThreeSixty::Competency.count", 1 do
      post :create, xhr: true, params: { :three_sixty_competency => {:title => "new title", :description => "new competency"}}
    end

    assert_response :success

    assert_equal programs(:org_primary), assigns(:competency).organization
    assert_equal "new competency", assigns(:competency).description
    assert_equal "new title", assigns(:competency).title
  end

  def test_edit_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    get :edit, params: { :id => three_sixty_competencies(:leadership).id}
    assert_redirected_to new_session_path
  end

  def test_edit_non_admin_permission_denied
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :ram

    assert_permission_denied do
      get :edit, params: { :id => programs(:org_primary).three_sixty_competencies.first.id}
    end
  end

  def test_edit_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    get :edit, xhr: true, params: { :id => three_sixty_competencies(:leadership).id}
    assert_response :success

    assert_equal three_sixty_competencies(:leadership), assigns(:competency)
  end

  def test_update_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    get :update, params: { :id => three_sixty_competencies(:leadership).id}
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

    assert_no_difference "ThreeSixty::Competency.count" do
      post :update, xhr: true, params: { :id => three_sixty_competencies(:leadership).id, :three_sixty_competency => {:title => "Delegating"}}
    end
    assert_response :success

    assert_equal three_sixty_competencies(:leadership), assigns(:competency)
    assert_nil assigns(:competency).description
    assert_equal "Delegating", assigns(:competency).title
    assert_equal "Leadership", three_sixty_competencies(:leadership).reload.title
  end

  def test_update_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    assert_no_difference "ThreeSixty::Competency.count" do
      post :update, xhr: true, params: { :id => three_sixty_competencies(:leadership).id, :three_sixty_competency => {:title => "updated title"}}
    end
    assert_response :success

    assert_equal three_sixty_competencies(:leadership), assigns(:competency)
    assert_nil assigns(:competency).description
    assert_equal "updated title", assigns(:competency).title
    assert_equal "updated title", three_sixty_competencies(:leadership).reload.title
  end

  def test_destroy_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    assert_no_difference "ThreeSixty::Competency.count" do
      delete :destroy, xhr: true, params: { :id => programs(:org_primary).three_sixty_competencies.first.id}
    end
  end

  def test_destroy_non_admin_permission_denied
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :ram

    assert_no_difference "ThreeSixty::Competency.count" do
      assert_permission_denied do
        delete :destroy, xhr: true, params: { :id => programs(:org_primary).three_sixty_competencies.first.id}
      end
    end
  end

  def test_destroy_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    assert_difference "ThreeSixty::Competency.count", -1 do
      delete :destroy, xhr: true, params: { :id => three_sixty_competencies(:leadership).id}
    end
    assert_response :success
  end
end
