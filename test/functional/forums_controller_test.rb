require_relative './../test_helper.rb'

class ForumsControllerTest < ActionController::TestCase

  ## PROGRAM FORUM: SHOW ##
  def test_program_forum_show_permission_denied
    current_user_is :f_mentor
    assert_permission_denied do
      get :show, params: { id: forums(:forums_1).id}
    end
  end

  def test_program_forum_show_feature_disabled
    programs(:albers).enable_feature(FeatureName::FORUMS, false)

    current_user_is :f_mentor
    assert_permission_denied do
      get :show, params: { id: forums(:common_forum).id}
    end
  end

  def test_program_forum_show
    user = users(:f_mentor)
    forum = forums(:common_forum)
    topics = 11.times.collect { create_topic }

    current_user_is user
    assert_difference "ActivityLog.count" do
      get :show, params: { page: 1, id: forum.id}
    end
    assert_response :success
    assert_equal forum, assigns(:forum)
    assert_equal topics[1..10].reverse, assigns(:topics)

    assert_no_difference "ActivityLog.count" do
      get :show, params: { page: 2, id: forum.id}
    end
    assert_response :success
    assert_equal [topics[0]], assigns(:topics)
    assert_equal ActivityLog::Activity::FORUM_VISIT, ActivityLog.last.activity
  end

  ## GROUP FORUM: SHOW ##
  def test_group_forum_show_permission_denied
    group = groups(:mygroup)
    forum = forums(:common_forum)
    forum.update_attribute(:group_id, group.id)
    assert_false group.forum_enabled?

    current_user_is group.mentors.first
    assert_permission_denied do
      get :show, params: { id: forum.id}
    end
  end

  def test_group_forum_show_non_group_member
    group_forum_setup

    current_user_is users(:f_student)
    assert_permission_denied do
      get :show, params: { id: @forum.id}
    end
  end

  def test_group_forum_show
    group_forum_setup
    user = @group.mentors.first
    topics = 2.times.collect { create_topic(forum: @forum, user: user) }

    @controller.expects(:prepare_template).once
    @controller.expects(:update_login_count).once
    @controller.expects(:update_last_visited_tab).once
    current_user_is user
    assert_difference "ActivityLog.count" do
      get :show, params: { id: @forum.id}
    end
    assert_response :success
    assert_equal topics[0..1].reverse, assigns(:topics)
    assert_equal ActivityLog::Activity::PROGRAM_VISIT, ActivityLog.last.activity
  end

  def test_group_forum_show_from_email
    group_forum_setup
    user = @group.mentors.first
    topics = 2.times.collect { create_topic(forum: @forum, user: user) }

    @controller.expects(:prepare_template).once
    @controller.expects(:update_login_count).once
    @controller.expects(:update_last_visited_tab).once
    current_user_is user
    topic_id = @forum.topics.first.id
    assert_difference "ActivityLog.count" do
      get :show, params: {id: @forum.id, topic_id: topic_id}
    end
    assert_response :success
    assert_equal topic_id, assigns(:topic_id_to_view).to_i
  end

  def test_group_forum_for_homepage
    group_forum_setup
    user = @group.mentors.first
    topics = 2.times.collect { create_topic(forum: @forum, user: user) }
    current_user_is user
    get :show, xhr: true, params: { id: @forum.id, home_page: "true"}
    assert_response :success
    assert assigns(:home_page)
    assert_equal topics[0..1].reverse, assigns(:topics)
  end

  def test_group_forum_show_admin_visit
    group_forum_setup

    @controller.expects(:prepare_template).once
    @controller.expects(:update_login_count).once
    @controller.expects(:update_last_visited_tab).once
    current_user_is users(:f_admin)
    get :show, params: { id: @forum.id}
    assert_response :success
    assert_empty assigns(:topics)
  end

  ## NEW ##
  def test_new_permission_denied
    current_user_is :f_mentor_student
    assert_permission_denied do
      get :new
    end
  end

  def test_new_feature_disabled
    programs(:albers).enable_feature(FeatureName::FORUMS, false)
    current_user_is :f_admin
    assert_permission_denied do
      get :new
    end
  end

  def test_new
    current_user_is :f_admin
    get :new
    assert_response :success
    assert assigns(:forum).new_record?
  end

  ## CREATE ##
  def test_create_permission_denied
    current_user_is :f_mentor
    assert_permission_denied do
      post :create, params: { forum: { name: "Forum 1", access_role_names: [RoleConstants::MENTOR_NAME] }}
    end
  end

  def test_create_feature_disabled
    programs(:albers).enable_feature(FeatureName::FORUMS, false)
    current_user_is :f_admin
    assert_permission_denied do
      post :create, params: { forum: { name: "Forum 1", access_role_names: [RoleConstants::MENTOR_NAME] }}
    end
  end

  def test_create_invalid_params
    current_user_is :f_admin
    assert_no_difference "Forum.count" do
      post :create, params: { forum: { name: "Forum 1", access_role_names: [] }}
    end
    assert_response :success
    assert_equal "Forum 1", assigns(:forum).name
    assert_equal programs(:albers), assigns(:forum).program
  end

  def test_create
    current_user_is :f_admin
    assert_difference "Forum.count" do
      post :create, params: { forum: { name: "Forum 1", access_role_names: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], description: "For Mentors & Students" }}
    end
    assert_redirected_to forums_path(filter: Forum::For::ALL)
    assert_equal "The new forum has been successfully created", flash[:notice]

    forum = Forum.last
    assert_equal "Forum 1", forum.name
    assert_equal programs(:albers), forum.program
    assert_equal_unordered [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], forum.access_role_names
    assert_equal "For Mentors & Students", forum.description
  end

  # EDIT ##
  def test_edit_permission_denied
    current_user_is :f_student
    assert_permission_denied do
      get :edit, params: { id: forums(:common_forum).id}
    end
  end

  def test_edit_feature_disabled
    programs(:albers).enable_feature(FeatureName::FORUMS, false)

    current_user_is :f_student
    assert_permission_denied do
      get :edit, params: { id: forums(:common_forum).id}
    end
  end

  def test_edit_restricted_for_group_forum
    forum = forums(:common_forum)
    forum.update_attribute(:group_id, groups(:mygroup).id)

    current_user_is :f_admin
    assert_permission_denied do
      get :edit, params: { id: forum.id}
    end
  end

  def test_edit
    forum = forums(:common_forum)

    current_user_is :f_admin
    get :edit, params: { id: forum.id}
    assert_response :success
    assert_template "new"
    assert_equal forum, assigns(:forum)
  end

  ## UPDATE ##
  def test_update_permission_denied
    current_user_is :f_student
    assert_permission_denied do
      put :update, params: { forum: { name: "Common Forum 2.o" }, id: forums(:common_forum).id}
    end
  end

  def test_update_feature_disabled
    programs(:albers).enable_feature(FeatureName::FORUMS, false)

    current_user_is :f_admin
    assert_permission_denied do
      put :update, params: { forum: { name: "Common Forum 2.o" }, id: forums(:common_forum).id}
    end
  end

  def test_update_restricted_for_group_forum
    forum = forums(:common_forum)
    forum.update_attribute(:group_id, groups(:mygroup).id)

    current_user_is :f_admin
    assert_permission_denied do
      put :update, params: { forum: { name: "Common Forum 2.o" }, id: forum.id}
    end
  end

  def test_update_invalid_params
    forum = forums(:common_forum)

    current_user_is :f_admin
    put :update, params: { forum: { name: "" }, id: forum.id}
    assert_response :success
    assert_template "new"
    assert_equal "Common forum", forum.reload.name
  end

  def test_update
    forum = forums(:common_forum)

    current_user_is :f_admin
    put :update, params: { forum: { name: "Common Forum 2.o", description: "Desc.", access_role_names: [RoleConstants::MENTOR_NAME] }, id: forum.id}
    assert_redirected_to forums_path(filter: Forum::For::ALL)
    assert_equal "The changes have been saved", flash[:notice]

    forum.reload
    assert_equal "Common Forum 2.o", forum.name
    assert_equal "Desc.", forum.description
    assert_equal_unordered [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], forum.access_role_names
  end

  ## INDEX ##
  def test_index_permission_denied
    current_user_is :f_student
    assert_permission_denied do
      get :index
    end
  end

  def test_index_feature_disabled
    programs(:albers).enable_feature(FeatureName::FORUMS, false)

    current_user_is :f_admin
    assert_permission_denied do
      get :index
    end
  end

  def test_index
    group_forum_setup
    forums = [forums(:forums_1)]|[forums(:forums_2)]|[forums(:common_forum)]
    forum_subscriptions = Subscription.where(ref_obj_type: Forum.name).where(ref_obj_id: forums.collect(&:id)).group('ref_obj_id').count("id")
    forum_posts = Topic.joins(:posts).where(forum_id: forums.collect(&:id)).group('forum_id').count("posts.id")

    current_user_is :f_admin
    get :index
    assert_response :success
    assert_equal Forum::For::ALL, assigns(:filter_field)
    assert_equal forums.sort_by { |f| -f[:id] }, assigns(:forums)
    assert_equal forum_subscriptions, assigns(:forum_subscriptions)
    assert_equal forum_posts, assigns(:forum_posts)
  end

  def test_index_with_role_filter
    forums = [forums(:forums_2), forums(:common_forum)]
    forum_subscriptions = Subscription.where(ref_obj_type: Forum.name).where(ref_obj_id: forums.collect(&:id)).group('ref_obj_id').count("id")
    forum_posts = Topic.joins(:posts).where(forum_id: forums.collect(&:id)).group('forum_id').count("posts.id")

    current_user_is :f_admin
    get :index, params: { filter: RoleConstants::MENTOR_NAME}
    assert_response :success
    assert_equal RoleConstants::MENTOR_NAME, assigns(:filter_field)
    assert_equal_unordered forums, assigns(:forums)
    assert_equal forum_subscriptions, assigns(:forum_subscriptions)
    assert_equal forum_posts, assigns(:forum_posts)
  end

  ## DESTROY ##
  def test_destroy_permission_denied
    current_user_is :f_mentor_student
    assert_permission_denied do
      post :destroy, params: { id: forums(:common_forum).id}
    end
  end

  def test_destroy_feature_disabled
    programs(:albers).enable_feature(FeatureName::FORUMS, false)

    current_user_is :f_admin
    assert_permission_denied do
      post :destroy, params: { id: forums(:common_forum).id}
    end
  end

  def test_destroy_restricted_for_group_forum
    forum = forums(:common_forum)
    forum.update_attribute(:group_id, groups(:mygroup).id)

    current_user_is :f_admin
    assert_permission_denied do
      post :destroy, params: { id: forum.id}
    end
  end

  def test_destroy
    current_user_is :f_admin
    assert_difference "Forum.count", -1 do
      post :destroy, params: { id: forums(:common_forum).id}
    end
    assert_redirected_to forums_path(filter: Forum::For::ALL)
    assert_equal "The forum has been successfully removed", flash[:notice]
  end

  ## SUBSCRIPTION ##
  def test_subscription_permission_denied
    current_user_is :f_student
    assert_permission_denied do
      get :subscription, params: { id: forums(:forums_2).id, subscribe: "true"}
    end
  end

  def test_subscription_feature_disabled
    programs(:albers).enable_feature(FeatureName::FORUMS, false)

    current_user_is :f_mentor
    assert_permission_denied do
      get :subscription, params: { id: forums(:forums_2).id, subscribe: "false"}
    end
  end

  def test_subscription_restricted_for_group_forum
    forum = forums(:forums_2)
    forum.update_attribute(:group_id, groups(:mygroup).id)

    current_user_is :f_mentor
    assert_permission_denied do
      get :subscription, params: { id: forum.id, subscribe: "false"}
    end
  end

  def test_subscription_subscribe
    forum = forums(:forums_2)
    user = users(:f_mentor_student)
    assert_false forum.subscribed_by?(user)

    current_user_is user
    assert_difference "Subscription.count" do
      get :subscription, params: { id: forum.id, subscribe: "true"}
    end
    assert_redirected_to forum_path(forum)
    assert_equal "You have joined '#{forum.name}'", flash[:notice]

    assert forum.subscribed_by?(user)
  end

  def test_subscription_unsubscribe
    forum = forums(:forums_2)
    user = users(:f_mentor)
    topic = create_topic(forum: forum, user: user)
    assert forum.subscribed_by?(user)
    assert topic.subscribed_by?(user)

    current_user_is user
    assert_difference "Subscription.count", -2 do
      get :subscription, params: { id: forum.id, subscribe: "false"}
    end
    assert_redirected_to forum_path(forum)
    assert_equal "You have unsubscribed from '#{forum.name}'", flash[:notice]

    assert_false forum.subscribed_by?(user)
    assert_false topic.subscribed_by?(user)
  end
end