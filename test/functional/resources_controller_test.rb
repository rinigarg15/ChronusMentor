require_relative './../test_helper.rb'

class ResourcesControllerTest < ActionController::TestCase

  def test_index_auth
    programs(:org_primary).enable_feature(FeatureName::RESOURCES, false)
    current_member_is :f_admin
    
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_RESOURCE_LIST).never
    assert_permission_denied do
      get :index
    end
  end

  def test_index_auth_enabled_at_program_level
    programs(:org_primary).enable_feature(FeatureName::RESOURCES, false)
    programs(:albers).enable_feature(FeatureName::RESOURCES, true)
    current_member_is :f_admin
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_RESOURCE_LIST).once
    get :index
    assert_response :success
  end

  def test_search
    current_user_is :f_admin
    current_program_is :albers

    #testing a correct term(not a stopword)
    get :index, params: { :search => "mentor"}
    resources = [resources(:resources_1),  resources(:resources_2),  resources(:resources_5)]
    assert_response :success
    assert_template 'index'
    assert_equal resources.collect(&:id), assigns(:resources).collect(&:id)
  end

  def test_to_check_search_query_is_escaped
    current_user_is :f_admin
    current_program_is :albers
    assert_nothing_raised do
      get :index, params: { :search => "mentor/"}
    end
    resources = [resources(:resources_1),  resources(:resources_2),  resources(:resources_5)]
    assert_response :success
    assert_template 'index'
    assert_equal resources.collect(&:id), assigns(:resources).collect(&:id)
  end

  def test_resource_tab_end_user
    programs(:org_primary).enable_feature(FeatureName::RESOURCES, false)
    programs(:albers).enable_feature(FeatureName::RESOURCES, true)

    current_member_is :f_mentor
    current_program_is :albers

    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME).id
    create_resource(:programs => {programs(:albers) => [m1]})
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_RESOURCE_LIST).once
    get :index
    assert_response :success
    assert_select "li a", :text => "Resources"
  end

  def test_reorder_auth
    programs(:org_primary).enable_feature(FeatureName::RESOURCES)
    current_member_is :f_admin

    put :reorder
    assert_redirected_to programs_list_path
  end

  def test_index_with_whitelisted_sort_option
    programs(:org_primary).enable_feature(FeatureName::RESOURCES)
    current_member_is :f_admin

    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME).id
    s1 = programs(:albers).get_role(RoleConstants::STUDENT_NAME).id
    s2 = programs(:nwen).get_role(RoleConstants::STUDENT_NAME).id

    r1 = create_resource(:programs => {programs(:albers) => [m1, s1], programs(:nwen) => [s2]})
    r2 = create_resource(:programs => {programs(:albers) => [m1]})
    r3 = create_resource(:programs => {programs(:albers) => [s1]})
    r4 = create_resource(:programs => {programs(:nwen) => [s2]})

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_RESOURCE_LIST).once
    get :index, params: { sort: "title", order: "ASC"}
    assert_response :success
    assert 'title', assigns(:sort_field)
    assert 'ASC', assigns(:sort_order)
  end

  def test_index_with_non_whitelisted_sort_option
    programs(:org_primary).enable_feature(FeatureName::RESOURCES)
    current_member_is :f_admin

    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME).id
    s1 = programs(:albers).get_role(RoleConstants::STUDENT_NAME).id
    s2 = programs(:nwen).get_role(RoleConstants::STUDENT_NAME).id

    r1 = create_resource(:programs => {programs(:albers) => [m1, s1], programs(:nwen) => [s2]})
    r2 = create_resource(:programs => {programs(:albers) => [m1]})
    r3 = create_resource(:programs => {programs(:albers) => [s1]})
    r4 = create_resource(:programs => {programs(:nwen) => [s2]})

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_RESOURCE_LIST).once
    get :index, params: { sort: "hello", order: "ASCII"}
    assert_response :success
    assert 'position', assigns(:sort_field)
    assert 'ASC', assigns(:sort_order)
  end

  def test_index_admin_default_sorting
    programs(:org_primary).enable_feature(FeatureName::RESOURCES)
    current_member_is :f_admin

    r1 = create_resource(:title => "A")
    r2 = create_resource(:title => "C")
    r3 = create_resource(:title => "B")

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_RESOURCE_LIST).once
    get :index
    assert_response :success
    assert_equal ["A", "B", "C", "Guide to Timely and Efficient Goal Setting", "How to Get Matched", "How to Use Your Connection Plan", "Mentee Handbook", "Mentor Handbook", "Working with the Mentoring Connection Plan"], assigns(:resources).collect(&:title)
  end

  def test_index_admin_with_reorder
    programs(:org_primary).enable_feature(FeatureName::RESOURCES)
    current_user_is :f_admin
    current_program_is :albers

    resources = users(:f_admin).accessible_resources(admin_view: true)

    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME).id
    s1 = programs(:albers).get_role(RoleConstants::STUDENT_NAME).id

    r1 = create_resource(:programs => {programs(:albers) => [m1, s1]})
    r2 = create_resource(:programs => {programs(:albers) => [m1]})
    r3 = create_resource(:programs => {programs(:albers) => [s1]})


    resources += [r1, r2, r3]

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_RESOURCE_LIST).once
    get :index, params: { reorder: :true}
    assert_response :success

    assert assigns(:admin_view)
    assert_equal resources, assigns(:resources)
    assert assigns(:reorder_view)
  end

  def test_reorder_admin
    programs(:org_primary).enable_feature(FeatureName::RESOURCES)
    current_user_is :f_admin
    current_program_is :albers
    programs(:org_primary).resources.delete_all

    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME).id
    s1 = programs(:albers).get_role(RoleConstants::STUDENT_NAME).id

    r1 = create_resource(:programs => {programs(:albers) => [m1, s1]})
    r2 = create_resource(:programs => {programs(:albers) => [m1]})
    r3 = create_resource(:programs => {programs(:albers) => [s1]})

    put :reorder, params: { new_order: [r1.id, r3.id, r2.id]}
    assert_response :success
    assert_equal [r1, r3, r2], users(:f_admin).accessible_resources(admin_view: true)
  end

  def test_index_end_user_req_program
    programs(:org_primary).enable_feature(FeatureName::RESOURCES)
    current_member_is :f_mentor

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_RESOURCE_LIST).never
    get :index
    assert_select "a", :title => 'Mentor Handbook', :count => 1
  end

  def test_index_end_user
    programs(:org_primary).enable_feature(FeatureName::RESOURCES)
    current_user_is :f_mentor

    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME).id
    s1 = programs(:albers).get_role(RoleConstants::STUDENT_NAME).id
    s2 = programs(:nwen).get_role(RoleConstants::STUDENT_NAME).id

    r1 = create_resource(:programs => {programs(:albers) => [m1, s1], programs(:nwen) => [s2]})
    r2 = create_resource(:programs => {programs(:albers) => [m1]})
    r3 = create_resource(:programs => {programs(:albers) => [s1]})
    r4 = create_resource(:programs => {programs(:nwen) => [s2]})

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_RESOURCE_LIST).once
    get :index
    assert_response :success
    assert_false assigns(:admin_view)
    assert_equal [r1, r2], assigns(:resources)
  end

  def test_index_accessing_resource_user_does_not_exist_in_program
    programs(:org_no_subdomain).enable_feature(FeatureName::RESOURCES)
    current_program_is programs(:no_subdomain)
    current_member_is members(:dormant_member)

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_RESOURCE_LIST).never
    assert_nil assigns(:current_user)
    get :index

    assert_false assigns(:admin_view)
    assert_redirected_to root_path
    assert_equal "Permission Denied. You need to join #{programs(:no_subdomain).name} to access this link.", flash[:error]
  end

  def test_show_admin
    programs(:org_primary).enable_feature(FeatureName::RESOURCES)
    current_member_is :f_admin

    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME).id
    r1 = create_resource(:programs => {programs(:albers) => [m1]})
    r2 = create_resource(:title => "A")
    r3 = create_resource(:title => "C")
    r4 = create_resource(:title => "B")

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_RESOURCE, {context_object: r1.title}).once
    get :show, params: { :id => r1.id}

    assert assigns(:admin_view)
    assert_equal r1, assigns(:resource)
    assert_equal ["Working with the Mentoring Connection Plan", "How to Use Your Connection Plan", "Guide to Timely and Efficient Goal Setting", "How to Get Matched", "Mentor Handbook", "Mentee Handbook", "New resource", "A", "C", "B"], assigns(:resources).collect(&:title)
  end

  def test_show_end_user_req_program
    programs(:org_primary).enable_feature(FeatureName::RESOURCES)
    current_member_is :f_mentor
    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME).id
    r1 = create_resource(:programs => {programs(:albers) => [m1]})

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_RESOURCE, {context_object: r1.title}).never
    get :show, params: { :id => r1.id}
    assert_redirected_to programs_list_path
  end

  def test_show_end_user_accessible_resource
    programs(:org_primary).enable_feature(FeatureName::RESOURCES)
    current_user_is :f_mentor

    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME).id
    r1 = create_resource(:programs => {programs(:albers) => [m1]})

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_RESOURCE, {context_object: r1.title}).once
    get :show, params: { :id => r1.id}

    assert_false assigns(:admin_view)
    assert_equal r1, assigns(:resource)
    assert_equal 1, assigns(:resource).view_count
  end

  def test_show_end_user_unaccessible_resource
    programs(:org_primary).enable_feature(FeatureName::RESOURCES)
    current_user_is :f_mentor

    m1 = programs(:albers).get_role(RoleConstants::STUDENT_NAME).id
    r1 = create_resource(:programs => {programs(:albers) => [m1]})

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_RESOURCE, {context_object: r1.title}).never
    get :show, params: { :id => r1.id}

    assert_false assigns(:admin_view)
    assert_match "You are not authorized to access the page", flash[:error]
    assert_redirected_to resources_path
  end

  def test_show_accessing_resource_user_does_not_exist_in_program
    programs(:org_primary).enable_feature(FeatureName::RESOURCES)
    current_member_is members(:dormant_member)

    m1 = programs(:albers).get_role(RoleConstants::STUDENT_NAME).id
    r1 = create_resource(:programs => {programs(:albers) => [m1]})

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_RESOURCE, {context_object: r1.title}).never
    get :show, params: { :id => r1.id}

    assert_false assigns(:admin_view)
    assert_match "Oops! We cannot find that page.", flash[:error]
    assert_redirected_to resources_path
  end

  def test_show_admin_accessing_invalid_resource
    programs(:org_primary).enable_feature(FeatureName::RESOURCES)
    current_member_is :f_admin

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_RESOURCE, {context_object: ''}).never
    get :show, params: { :id => 0}

    assert assigns(:admin_view)
    assert_match "Oops! We cannot find that page.", flash[:error]
    assert_redirected_to resources_path
  end

  def test_new_auth
    programs(:org_primary).enable_feature(FeatureName::RESOURCES)
    current_member_is :f_mentor

    assert_permission_denied do
      get :new
    end
  end

  def test_new
    programs(:org_primary).enable_feature(FeatureName::RESOURCES)
    current_member_is :f_admin

    get :new
    assert_response :success
    assert assigns(:resource).new_record?
  end

  def test_create_success
    programs(:org_primary).enable_feature(FeatureName::RESOURCES)
    current_member_is :f_admin
    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME)

    assert_difference "RoleResource.count" do
      assert_difference "ResourcePublication.count" do
        assert_difference "Resource.count" do
          post :create, params: { :resource => {:title => "Frank Underwood", :content => "Claire Underwood", :role_ids => ["#{m1.id}"], :program_ids => ["#{programs(:albers).id}"]}}
        end
      end
    end

    res = Resource.last
    assert_equal "Frank Underwood", res.title
    assert_equal "Claire Underwood", res.content
    assert_equal 7, res.resource_publications.first.position
    assert_equal [m1], res.roles
    assert_redirected_to resources_path(:resource_id => res.id)
    assert_match(/The #{resources_term} has been successfully published/, flash[:notice])
    assert_match(resource_path(res), flash[:notice])
  end

  def test_create_success_with_vulnerable_content_with_version_v1
    programs(:org_primary).enable_feature(FeatureName::RESOURCES)
    current_member_is :f_admin
    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME)
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v1")

    assert_no_difference "VulnerableContentLog.count" do
      assert_difference "RoleResource.count" do
        assert_difference "ResourcePublication.count" do
          assert_difference "Resource.count" do
            post :create, params: { :resource => {:title => "Frank Underwood", :content => "Claire Underwood<script>alert(10);</script>", :role_ids => ["#{m1.id}"], :program_ids => ["#{programs(:albers).id}"]}}
          end
        end
      end
    end
  end

  def test_create_success_with_vulnerable_content_with_version_v2
    programs(:org_primary).enable_feature(FeatureName::RESOURCES)
    current_member_is :f_admin
    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME)
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v2")

    assert_difference "VulnerableContentLog.count" do
      assert_difference "RoleResource.count" do
        assert_difference "ResourcePublication.count" do
          assert_difference "Resource.count" do
            post :create, params: { :resource => {:title => "Frank Underwood", :content => "Claire Underwood<script>alert(10);</script>", :role_ids => ["#{m1.id}"], :program_ids => ["#{programs(:albers).id}"]}}
          end
        end
      end
    end
  end

  def test_create_success_track_level
    programs(:albers).enable_feature(FeatureName::RESOURCES)
    current_member_is :f_admin
    current_program_is :albers
    admin_view = AdminView.find_by(title: "All Users")
    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME)
    assert_difference "RoleResource.count" do
      assert_difference "ResourcePublication.count" do
        assert_difference "Resource.count" do
          post :create, params: { :resource => {:title => "R1", :content => "Resource Content", :role_ids => ["#{m1.id}"], :program_ids => ["#{programs(:albers).id}"], :resource_publications => {:show_in_quick_links => "1"}}}
        end
      end
    end

    res = Resource.last
    assert_equal "R1", res.title
    assert_equal "Resource Content", res.content
    assert_equal 7, res.resource_publications.first.position
    assert res.resource_publications.find_by(program_id: programs(:albers).id).show_in_quick_links
    assert_equal [m1], res.roles
    assert_redirected_to resources_path(:resource_id => res.id)
    assert_match(/The #{resources_term} has been successfully published/, flash[:notice])
    assert_match(resource_path(res), flash[:notice])

    post :create, params: { :resource => {:title => "R1", :content => "Resource Content", :role_ids => ["#{m1.id}"], :program_ids => ["#{programs(:albers).id}"], :resource_publications => {:show_in_quick_links => "", admin_view_id: admin_view.id}} }
    res = Resource.last
    assert_equal admin_view.id, res.resource_publications.find_by(program_id: programs(:albers).id).admin_view_id
  end

  def test_index_invalidate_xss_attack
    programs(:org_primary).enable_feature(FeatureName::RESOURCES)
    current_member_is :f_admin

    res = Resource.last
    get :index, params: { :resource_id => res.id}
    assert_match "jQueryScrollTo('#resource_#{res.id}', true);", @response.body

    get :index, params: { :resource_id => "#{res.id}',true),alert('hi')//"}
    assert_match "jQueryScrollTo('#resource_#{res.id}', true);", @response.body
  end

  def test_edit
    programs(:org_primary).enable_feature(FeatureName::RESOURCES)
    current_member_is :f_admin

    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME).id
    r1 = create_resource(:programs => {programs(:albers) => [m1]})

    get :edit, params: { :id => r1.id}
    assert_response :success
    assert_equal r1.id, assigns(:resource).id
  end

  def test_udpate_success
    programs(:org_primary).enable_feature(FeatureName::RESOURCES)
    current_member_is :f_admin

    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME)
    m2 = programs(:nwen).get_role(RoleConstants::MENTOR_NAME)
    s1 = programs(:albers).get_role(RoleConstants::STUDENT_NAME)
    s2 = programs(:nwen).get_role(RoleConstants::STUDENT_NAME)

    res = create_resource(:programs => {programs(:albers) => ["#{m1.id}", "#{s1.id}"], programs(:nwen) => ["#{s2.id}"]})
    assert_equal [m1, s1, s2], res.roles

    post :update, params: { :id => res.id, :resource => {:title => "Test title", :content => "Test content", :program_ids => ["#{programs(:nwen).id}", "#{programs(:albers).id}"], :role_ids => ["#{m2.id}", "#{s1.id}"]}}

    res.reload
    assert_equal "Test title", res.title
    assert_equal "Test content", res.content
    assert_equal [s1, m2], res.roles
    assert_redirected_to resources_path(:resource_id => res.id)
    assert_match(/The #{resources_term} has been successfully updated/, flash[:notice])
    assert_match(resource_path(res), flash[:notice])
  end

  def test_udpate_success_track_level
    programs(:albers).enable_feature(FeatureName::RESOURCES)
    current_member_is :f_admin
    current_program_is :albers
    admin_view = AdminView.find_by(title: "All Users")

    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME)
    s1 = programs(:albers).get_role(RoleConstants::STUDENT_NAME)

    res = create_resource(:programs => {programs(:albers) => ["#{m1.id}", "#{s1.id}"]})
    assert_equal [m1, s1], res.roles
    assert_false res.resource_publications.first.show_in_quick_links

    post :update, params: { :id => res.id, :resource => {:title => "Test title", :content => "Test content", :program_ids => ["#{programs(:albers).id}"], :role_ids => ["#{m1.id}"], :resource_publications => {:show_in_quick_links => true}}}

    res.reload
    # Title and Content For a Org Resource Shouldn't be updated in program view.
    assert_equal "New resource", res.title
    assert_equal "New content", res.content
    assert_equal [m1], res.roles
    assert res.resource_publications.first.show_in_quick_links
    assert_redirected_to resources_path(:resource_id => res.id)
    assert_match(/The #{resources_term} has been successfully updated/, flash[:notice])
    assert_match(resource_path(res), flash[:notice])

    post :update, params: { :id => res.id, :resource => {:title => "Test title", :content => "Test content", :program_ids => ["#{programs(:albers).id}"], :role_ids => ["#{m1.id}"], :resource_publications => {:show_in_quick_links => nil, admin_view_id: admin_view.id}} }
    res.reload
    assert_equal admin_view.id, res.resource_publications.first.admin_view_id
  end

  def test_udpate_success_organization_level
    programs(:albers).enable_feature(FeatureName::RESOURCES)
    current_member_is :f_admin

    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME)
    s1 = programs(:albers).get_role(RoleConstants::STUDENT_NAME)

    res = create_resource(:programs => {programs(:albers) => ["#{m1.id}", "#{s1.id}"]})
    assert_equal [m1, s1], res.roles
    assert_false res.resource_publications.first.show_in_quick_links

    post :update, params: { :id => res.id, :resource => {:title => "Test title", :content => "Test content", :program_ids => ["#{programs(:albers).id}"], :role_ids => ["#{m1.id}"], :resource_publications => {:show_in_quick_links => true}}}

    res.reload
    # Title and Content For a Org Resource Shouldn't be updated in program view.
    assert_equal "Test title", res.title
    assert_equal "Test content", res.content
    assert_equal [m1], res.roles
    assert_false res.resource_publications.first.show_in_quick_links
    assert_redirected_to resources_path(:resource_id => res.id)
    assert_match(/The #{resources_term} has been successfully updated/, flash[:notice])
    assert_match(resource_path(res), flash[:notice])
  end

  def test_udpate_success_with_vulnerable_content_with_version_v1
    programs(:albers).enable_feature(FeatureName::RESOURCES)
    current_member_is :f_admin

    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME)
    s1 = programs(:albers).get_role(RoleConstants::STUDENT_NAME)

    res = create_resource(:programs => {programs(:albers) => ["#{m1.id}", "#{s1.id}"]})
    assert_equal [m1, s1], res.roles
    assert_false res.resource_publications.first.show_in_quick_links
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v1")

    assert_no_difference "VulnerableContentLog.count" do
      post :update, params: { :id => res.id, :resource => {:title => "Test title", :content => "Test content<script>alert(10);</script>", :program_ids => ["#{programs(:albers).id}"], :role_ids => ["#{m1.id}"], :resource_publications => {:show_in_quick_links => true}}}
    end
  end

  def test_udpate_success_with_vulnerable_content_with_version_v2
    programs(:albers).enable_feature(FeatureName::RESOURCES)
    current_member_is :f_admin

    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME)
    s1 = programs(:albers).get_role(RoleConstants::STUDENT_NAME)

    res = create_resource(:programs => {programs(:albers) => ["#{m1.id}", "#{s1.id}"]})
    assert_equal [m1, s1], res.roles
    assert_false res.resource_publications.first.show_in_quick_links
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v2")

    assert_difference "VulnerableContentLog.count" do
      post :update, params: { :id => res.id, :resource => {:title => "Test title", :content => "Test content<script>alert(10);</script>", :program_ids => ["#{programs(:albers).id}"], :role_ids => ["#{m1.id}"], :resource_publications => {:show_in_quick_links => true}}}
    end
  end

  def test_destroy
    programs(:org_primary).enable_feature(FeatureName::RESOURCES)
    current_member_is :f_admin

    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME)
    s1 = programs(:albers).get_role(RoleConstants::STUDENT_NAME)
    s2 = programs(:nwen).get_role(RoleConstants::STUDENT_NAME)

    res = create_resource(:programs => {programs(:albers) => ["#{m1.id}", "#{s1.id}"], programs(:nwen) => ["#{s2.id}"]})
    assert_equal [m1, s1, s2], res.roles

    assert_difference "Resource.count", -1 do
      assert_difference "RoleResource.count", -3 do
        post :destroy, params: { :id => res.id}
      end
    end

    assert_redirected_to resources_path
    assert_equal "The #{resources_term} has been successfully removed", flash[:notice]
  end

  def test_custom_term_resources
    current_member_is :f_admin

    programs(:org_primary).enable_feature(FeatureName::RESOURCES)
    programs(:org_primary).customized_terms.find_by(term_type: CustomizedTerm::TermType::RESOURCE_TERM).update_attributes!(:pluralized_term => "Oranges")

    get :index
    assert_response :success

    assert_page_title "Oranges"
  end

  def test_show_edit_actions_to_admin_org_level
    programs(:org_primary).enable_feature(FeatureName::RESOURCES)
    current_member_is :f_admin

    get :index
    assert_response :success
    assert_select "a", :text => "Add new resource", :count => 2
    assert_select "a", :text => "Reorder resources", :count => 0
  end

  def test_show_edit_actions_to_admin_program_level
    programs(:org_primary).enable_feature(FeatureName::RESOURCES, false)
    programs(:albers).enable_feature(FeatureName::RESOURCES)
    current_user_is :f_admin
    current_program_is :albers

    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME).id
    r1 = create_resource(:programs => {programs(:albers) => [m1]})

    get :index
    assert_response :success

    assert_select "a", :text => "Add new resource", :count => 2
    assert_select "a", :text => "Reorder resources", :count => 2
  end

  def test_not_show_edit_actions_to_end_users
    programs(:org_primary).enable_feature(FeatureName::RESOURCES)
    current_member_is :f_mentor

    get :index
    assert_select "a", :text => "Add new resource", :count => 0
    assert_select "a", :text => "Reorder resources", :count => 0
  end

  def test_publish_org_resource_to_track
    programs(:org_primary).enable_feature(FeatureName::RESOURCES)
    current_member_is :f_admin
    current_program_is :albers
    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME).id
    s1 = programs(:albers).get_role(RoleConstants::STUDENT_NAME).id
    s2 = programs(:nwen).get_role(RoleConstants::STUDENT_NAME).id

    r = create_resource(:programs => {programs(:albers) => [m1, s1], programs(:nwen) => [s2]})

    get :index
    assert_response :success
  end

  def test_standalone_edit_after_program_destroy
    programs(:org_foster).enable_feature(FeatureName::RESOURCES)
    current_user_is :foster_admin

    m1 = programs(:foster).get_role(RoleConstants::MENTOR_NAME).id
    s1 = programs(:foster).get_role(RoleConstants::STUDENT_NAME).id

    r1 = create_resource(:organization => programs(:org_foster), :programs => {programs(:foster) => [m1, s1]})

    current_program_is :foster

    get :edit, params: { :id => r1.id}
    assert_response :success
    assert_equal r1, assigns(:resource)
  end

  def test_standalone_update_after_program_destroy
    programs(:org_foster).enable_feature(FeatureName::RESOURCES)
    current_user_is :foster_admin

    m1 = programs(:foster).get_role(RoleConstants::MENTOR_NAME).id
    s1 = programs(:foster).get_role(RoleConstants::STUDENT_NAME).id

    r1 = create_resource(:organization => programs(:org_foster), :programs => {programs(:foster) => [m1, s1]})

    post :update, params: { :id => r1.id, :resource => {:title => "R1", :content => "Test content", :program_ids => ["#{programs(:foster).id}"]}}

    r1.reload
    assert_equal "R1", r1.title
    assert_equal "Test content", r1.content
    assert_redirected_to resources_path(:resource_id => r1.id)
    assert_match(/The #{resources_term} has been successfully updated/, flash[:notice])
    assert_match(resource_path(r1), flash[:notice])
  end

  def test_standalone_index_after_program_destroy
    programs(:org_foster).enable_feature(FeatureName::RESOURCES)
    current_user_is :foster_admin

    m1 = programs(:foster).get_role(RoleConstants::MENTOR_NAME).id
    s1 = programs(:foster).get_role(RoleConstants::STUDENT_NAME).id

    r1 = create_resource(:organization => programs(:org_foster), :programs => {programs(:foster) => [m1, s1]})

    current_program_is :foster

    get :index
    assert_response :success
    assert_select "#resource_#{r1.id}" do
      assert_select "i.icon-info-sign", false
    end
  end

   def test_should_mark_resource_as_helpful
    current_member_is :f_mentor
    current_program_is :albers
    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME).id
    s1 = programs(:albers).get_role(RoleConstants::STUDENT_NAME).id
    resource = create_resource(:programs => {programs(:albers)=> [m1, s1]})

    get :rate, xhr: true, params: { :id => resource.id, :rating => Resource::RatingType::HELPFUL}
    assert_response :success
    assert_equal assigns(:resource), resource
    assert_equal assigns(:resource).ratings.first, Rating.last
    assert_equal(1, resource.reload.ratings.count)

    get :rate, xhr: true, params: { :id => resource.id, :rating => Resource::RatingType::UNHELPFUL }
    assert_response :success
    assert_equal assigns(:resource), resource
    assert_equal assigns(:resource).reload.ratings.first, Rating.last
    assert_equal(1, resource.reload.ratings.count)
  end

  def test_should_mark_resource_as_unhelpful
    current_member_is :f_student
    current_program_is :albers
    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME).id
    s1 = programs(:albers).get_role(RoleConstants::STUDENT_NAME).id
    resource = create_resource(:programs => {programs(:albers)=> [m1, s1]})

    get :rate, xhr: true, params: { :rating => Resource::RatingType::UNHELPFUL , :id => resource.id}
    assert_response :success
    assert_equal assigns(:resource), resource
    assert_equal assigns(:resource).ratings.first, Rating.last
    assert_equal(1, resource.reload.ratings.count)
    assert_instance_of AdminMessage, assigns(:admin_message)
  end

  def test_student_denied_access_should_not_mark_resource
    current_member_is :f_student
    current_program_is :albers
    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME).id
    resource = create_resource(:programs => {programs(:albers)=> [m1]})

    get :rate, xhr: true, params: { :rating => Resource::RatingType::HELPFUL, :id => resource.id}
    assert_match "You are not authorized to access the page", flash[:error]
    assert_redirected_to resources_path
  end

  def test_mentor_denied_access_should_not_mark_resource
    current_member_is :f_mentor
    current_program_is :albers
    m1 = programs(:albers).get_role(RoleConstants::STUDENT_NAME).id
    resource = create_resource(:programs => {programs(:albers)=> [m1]})

    get :rate, xhr: true, params: { :rating => Resource::RatingType::HELPFUL, :id => resource.id}
    assert_match "You are not authorized to access the page", flash[:error]
    assert_redirected_to resources_path
  end

  def test_admin_should_not_mark_resource
    current_member_is :f_admin
    current_program_is :albers
    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME).id
    resource = create_resource(:programs => {programs(:albers)=> [m1]})
    
    get :rate, xhr: true, params: { :rating => Resource::RatingType::HELPFUL, :id => resource.id}
    assert_match "You are not authorized to access the page", flash[:error]
    assert_redirected_to resources_path
  end

  def test_user_sending_question
    current_member_is :f_mentor
    current_program_is :albers
    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME).id
    s1 = programs(:albers).get_role(RoleConstants::STUDENT_NAME).id
    resource = create_resource(:programs => {programs(:albers)=> [m1, s1]})

    get :show_question, xhr: true, params: { :id => resource.id}
    assert_response :success
    assert_equal assigns(:resource), resource
    assert_instance_of AdminMessage, assigns(:admin_message)
  end

  def test_student_denied_access_to_ask_question
    current_member_is :f_student
    current_program_is :albers
    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME).id
    resource = create_resource(:programs => {programs(:albers)=> [m1]})

    get :show_question, xhr: true, params: { :id => resource.id}
    assert_match "You are not authorized to access the page", flash[:error]
    assert_redirected_to resources_path
  end

  def test_mentor_denied_access_should_to_ask_question
    current_member_is :f_mentor
    current_program_is :albers
    m1 = programs(:albers).get_role(RoleConstants::STUDENT_NAME).id
    resource = create_resource(:programs => {programs(:albers)=> [m1]})

    get :show_question, xhr: true, params: { :id => resource.id}
    assert_match "You are not authorized to access the page", flash[:error]
    assert_redirected_to resources_path
  end

  def test_admin_should_not_ask_question
    current_member_is :f_admin
    current_program_is :albers
    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME).id
    resource = create_resource(:programs => {programs(:albers)=> [m1]})
    
    get :show_question, xhr: true, params: { :id => resource.id}
    assert_match "You are not authorized to access the page", flash[:error]
    assert_redirected_to resources_path
  end

  private

  def resources_term
    programs(:org_primary).term_for(CustomizedTerm::TermType::RESOURCE_TERM).term_downcase
  end

end
