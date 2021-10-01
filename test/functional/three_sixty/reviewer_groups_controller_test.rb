require_relative './../../test_helper.rb'

class ThreeSixty::ReviewerGroupsControllerTest < ActionController::TestCase
  def test_any_action_without_feature_permission_denied
    assert_false programs(:org_primary).has_feature?(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    assert_permission_denied do
      get :index
    end

    assert_permission_denied do
      post :create
    end

    assert_permission_denied do
      delete :destroy, params: { :id => three_sixty_reviewer_groups(:three_sixty_reviewer_groups_2).id}
    end

    assert_permission_denied do
      get :edit, xhr: true, params: { :id => three_sixty_reviewer_groups(:three_sixty_reviewer_groups_2).id}
    end

    assert_permission_denied do
      post :update, xhr: true, params: { :id => three_sixty_reviewer_groups(:three_sixty_reviewer_groups_2).id}
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
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    get :index
    assert_response :success

    assert_equal programs(:org_primary).three_sixty_reviewer_groups.excluding_self_type, assigns(:reviewer_groups)
    assert_equal ThreeSixty::CommonController::Tab::SETTINGS, assigns(:active_tab)
    assert_select "form#three_sixty_reviewer_group_from_new"
  end

  def test_index_success_for_program_admin
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_user_is :ram

    get :index
    assert_response :success

    assert_equal programs(:org_primary).three_sixty_reviewer_groups.excluding_self_type, assigns(:reviewer_groups)
    assert_equal ThreeSixty::CommonController::Tab::SETTINGS, assigns(:active_tab)
    assert_no_select "form#three_sixty_reviewer_group_from_new"
  end

  def test_create_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    post :create
    assert_redirected_to new_session_path
  end

  def test_create_non_org_admin_permission_denied
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :ram

    assert_permission_denied do
      get :create
    end
  end

  def test_create_failure
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    # pick one of the existing name of reviewer group
    rg_name = three_sixty_reviewer_groups(:three_sixty_reviewer_groups_2).name

    assert_no_difference "ThreeSixty::ReviewerGroup.count" do
      post :create, xhr: true, params: { :three_sixty_reviewer_group => {:name => rg_name}}
    end
    assert_response :success

    assert_equal programs(:org_primary), assigns(:reviewer_group).organization
    assert_equal rg_name, assigns(:reviewer_group).name
    assert_equal 0, assigns(:reviewer_group).threshold
    assert_false assigns(:reviewer_group).valid?
  end

  def test_create_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    assert_difference "ThreeSixty::ReviewerGroup.count", 1 do
      post :create, xhr: true, params: { :three_sixty_reviewer_group => {:name => "New Reviewer Group"}}
    end
    assert_response :success

    assert_equal programs(:org_primary), assigns(:reviewer_group).organization
    assert_equal "New Reviewer Group", assigns(:reviewer_group).name
    assert_equal 0, assigns(:reviewer_group).threshold
  end

  def test_destroy_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    assert_no_difference "ThreeSixty::ReviewerGroup.count" do
      post :destroy, xhr: true, params: { :id => programs(:org_primary).three_sixty_reviewer_groups.last.id}
    end
  end

  def test_destroy_non_org_admin_permission_denied
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :ram

    assert_no_difference "ThreeSixty::ReviewerGroup.count" do
      assert_permission_denied do
        post :destroy, xhr: true, params: { :id => programs(:org_primary).three_sixty_reviewer_groups.last.id}
      end
    end
  end

  def test_destroy_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    assert_difference "ThreeSixty::ReviewerGroup.count", -1 do
      post :destroy, xhr: true, params: { :id => programs(:org_primary).three_sixty_reviewer_groups.last.id}
    end

    assert_response :success
  end

  def test_edit_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    get :edit, params: { :id => programs(:org_primary).three_sixty_reviewer_groups.last}
    assert_redirected_to new_session_path
  end

  def test_edit_non_org_admin_permission_denied
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :ram

    assert_permission_denied do
      get :edit, params: { :id => programs(:org_primary).three_sixty_reviewer_groups.last}
    end
  end

  def test_edit_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    get :edit, xhr: true, params: { :id => programs(:org_primary).three_sixty_reviewer_groups.last}
    assert_response :success

    assert_equal programs(:org_primary).three_sixty_reviewer_groups.last, assigns(:reviewer_group)
  end

  def test_update_not_logged_in
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_organization_is :org_primary

    post :update, params: { :id => three_sixty_reviewer_groups(:three_sixty_reviewer_groups_2).id}
    assert_redirected_to new_session_path
  end

  def test_update_non_org_admin_permission_denied
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :ram

    assert_permission_denied do
      post :update, params: { :id => three_sixty_reviewer_groups(:three_sixty_reviewer_groups_2).id}
    end
  end

  def test_update_failure
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    assert_equal "Line Manager", three_sixty_reviewer_groups(:three_sixty_reviewer_groups_2).name
    assert_equal 1, three_sixty_reviewer_groups(:three_sixty_reviewer_groups_2).threshold

    # pick one of the existing name of reviewer group
    rg_name = three_sixty_reviewer_groups(:three_sixty_reviewer_groups_3).name

    post :update, xhr: true, params: { :id => three_sixty_reviewer_groups(:three_sixty_reviewer_groups_2).id, :three_sixty_reviewer_group => {:name => rg_name, :threshold => '3132'}}

    assert_response :success

    assert_equal rg_name, assigns(:reviewer_group).name
    assert_equal 3132, assigns(:reviewer_group).threshold
    assert_false assigns(:reviewer_group).valid?
    assert_equal "Line Manager", three_sixty_reviewer_groups(:three_sixty_reviewer_groups_2).reload.name
    assert_equal 1, three_sixty_reviewer_groups(:three_sixty_reviewer_groups_2).threshold
  end

  def test_update_success
    programs(:org_primary).enable_feature(FeatureName::THREE_SIXTY)
    current_member_is :f_admin

    assert_equal "Line Manager", three_sixty_reviewer_groups(:three_sixty_reviewer_groups_2).name
    assert_equal 1, three_sixty_reviewer_groups(:three_sixty_reviewer_groups_2).threshold

    post :update, xhr: true, params: { :id => three_sixty_reviewer_groups(:three_sixty_reviewer_groups_2).id, :three_sixty_reviewer_group => {:name => "New Reviewer Group", :threshold => '3132'}}
    assert_response :success

    assert_equal programs(:org_primary), assigns(:reviewer_group).organization
    assert_equal "New Reviewer Group", assigns(:reviewer_group).name
    assert_equal 3132, assigns(:reviewer_group).threshold
    assert_equal "New Reviewer Group", three_sixty_reviewer_groups(:three_sixty_reviewer_groups_2).reload.name
    assert_equal 3132, three_sixty_reviewer_groups(:three_sixty_reviewer_groups_2).threshold
  end
end
