require_relative './../test_helper.rb'

class TopicsControllerTest < ActionController::TestCase

  ## INDEX ##
  def test_index
    forum = forums(:common_forum)

    current_user_is users(:f_admin)
    get :index, params: { forum_id: forum.id}
    assert_redirected_to forum_path(forum)
  end

  ## PROGRAM FORUM: SHOW ##
  def test_show_no_topic
    forum = forums(:forums_1)

    current_user_is users(:f_admin)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::READ_A_FORUM_POST, {:context_object => forum.name}).never
    get :show, params: { forum_id: forum.id, id: "0"}
    assert_redirected_to forum_path(forum)
  end

  def test_program_forum_show_permission_denied
    forum = forums(:forums_1)
    topic = create_topic(forum: forum)

    current_user_is users(:f_mentor)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::READ_A_FORUM_POST, {:context_object => forum.name}).never
    assert_permission_denied do
      get :show, params: { id: topic.id, forum_id: topic.forum_id}
    end
  end

  def test_program_forum_show_feature_disabled
    forum = forums(:forums_1)
    topic = create_topic(forum: forum)
    topic.program.enable_feature(FeatureName::FORUMS, false)

    current_user_is users(:f_student)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::READ_A_FORUM_POST, {:context_object => forum.name}).never
    assert_permission_denied do
      get :show, params: { id: topic.id, forum_id: topic.forum_id}
    end
  end

  def test_program_forum_show
    forum = forums(:forums_1)
    topic_1 = create_topic(forum: forum)
    topic_2 = create_topic(forum: forum)
    topic_3 = create_topic(forum: forum, sticky_position: 1)
    posts = 11.times.collect { create_post(topic: topic_1) }

    current_user_is users(:f_student)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::READ_A_FORUM_POST, {:context_object => forum.name}).once
    assert_difference "ActivityLog.count" do
      get :show, params: { page: 1, id: topic_1.id, forum_id: forum.id}
    end
    assert_response :success
    assert_equal_hash( {
      sort_field: "id",
      sort_order: "desc"
    }, assigns(:sort_fields))
    assert_equal [topic_3, topic_2], assigns(:recent_topics)
    assert_equal ActivityLog::Activity::FORUM_VISIT, ActivityLog.last.activity
  end

  def test_program_forum_show_sorting
    forum = forums(:forums_1)
    topic_1 = create_topic(forum: forum, sticky_position: 1)
    topic_2 = create_topic(forum: forum)
    post_1 = create_post(topic: topic_1)
    post_2 = create_post(topic: topic_1)
    create_post(topic: topic_2)

    current_user_is users(:f_student)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::READ_A_FORUM_POST, {:context_object => forum.name}).once
    get :show, params: { id: topic_1.id, forum_id: forum.id, sort_field: "id", sort_order: "asc"}
    assert_response :success
    assert_equal_hash( {
      sort_field: "id",
      sort_order: "asc"
    }, assigns(:sort_fields))
    assert_equal [post_1, post_2], assigns(:posts)
    assert_equal [topic_2], assigns(:recent_topics)
  end

  def test_program_forum_show_moderation_end_user
    user = users(:f_student)
    topic = create_topic
    posts = 3.times.collect { create_post(topic: topic, user: user) }
    3.times.collect { create_post(topic: topic, published: false, user: user) }

    current_user_is user
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::READ_A_FORUM_POST, {:context_object => topic.forum.name}).once
    get :show, params: { id: topic.id, forum_id: topic.forum_id}
    assert_response :success
    assert_equal posts.reverse, assigns(:posts)
    assert_empty assigns(:recent_topics)
  end

  def test_program_forum_show_moderation_admin
    user = users(:f_student)
    topic = create_topic
    posts = 3.times.collect { create_post(topic: topic, user: user) }
    posts += 3.times.collect { create_post(topic: topic, published: false, user: user) }

    current_user_is users(:f_admin)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::READ_A_FORUM_POST, {:context_object => topic.forum.name}).once
    get :show, params: { id: topic.id, forum_id: topic.forum_id}
    assert_response :success
    assert_equal posts.reverse, assigns(:posts)
    assert_empty assigns(:recent_topics)
  end

  ## GROUP FORUM: SHOW ##
  def test_group_forum_show_permission_denied
    group = groups(:mygroup)
    user = group.members.first
    topic = create_topic(user: user)
    topic.forum.update_attribute(:group_id, group.id)
    assert_false group.forum_enabled?

    current_user_is user
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::READ_A_FORUM_POST, {:context_object => group.name}).never
    assert_permission_denied do
      get :show, xhr: true, params: { id: topic.id, forum_id: topic.forum_id}
    end
  end

  def test_group_forum_show_non_group_member
    group_forum_setup
    topic = create_topic(user: @group.members.first, forum: @forum)

    current_user_is users(:f_student)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::READ_A_FORUM_POST, {:context_object => @group.name}).never
    assert_permission_denied do
      get :show, xhr: true, params: { forum_id: @forum.id, id: topic.id}
    end
  end

  def test_group_forum_show
    group_forum_setup
    mentor = @group.mentors.first
    student = @group.students.first
    topic = create_topic(forum: @forum, user: mentor)
    post_1 = create_post(topic: topic, user: mentor)
    post_2 = create_post(topic: topic, user: student)

    @controller.expects(:prepare_template).once
    @controller.expects(:update_login_count).once
    @controller.expects(:update_last_visited_tab).once
    current_user_is mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::READ_A_FORUM_POST, {:context_object => @group.name}).once
    assert_difference "ActivityLog.count" do
      get :show, params: { id: topic.id, forum_id: @forum.id}
    end
    assert_response :success
    assert_equal_hash( {
      sort_field: "id",
      sort_order: "desc"
    }, assigns(:sort_fields))
    assert_equal [post_2, post_1], assigns(:posts)
    assert_empty assigns(:recent_topics)
    assert_equal ActivityLog::Activity::PROGRAM_VISIT, ActivityLog.last.activity
  end

  def test_group_forum_show_admin_visit
    group_forum_setup
    topic = create_topic(forum: @forum, user: @group.members.first)

    @controller.expects(:prepare_template).once
    @controller.expects(:update_login_count).once
    @controller.expects(:update_last_visited_tab).once
    current_user_is users(:f_admin)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::READ_A_FORUM_POST, {:context_object => @group.name}).once
    get :show, xhr: true, params: { id: topic.id, forum_id: @forum.id}
    assert_response :success
    assert_equal_hash( {
      sort_field: "id",
      sort_order: "desc"
    }, assigns(:sort_fields))
    assert_empty assigns(:posts)
    assert_empty assigns(:recent_topics)
  end

  ## PROGRAM FORUM: CREATE ##
  def test_program_forum_create_permission_denied
    current_user_is users(:f_mentor)
    assert_permission_denied do
      post :create, params: { forum_id: forums(:forums_1).id, topic: { title: "Topic 1", body: "Desc." }}
    end
  end

  def test_program_forum_create_feature_disabled
    programs(:albers).enable_feature(FeatureName::FORUMS, false)

    current_user_is users(:f_student)
    assert_permission_denied do
      post :create, params: { forum_id: forums(:forums_1).id, topic: { title: "Topic 1", body: "Desc." }}
    end
  end

  def test_program_forum_create_invalid_params
    forum = forums(:forums_1)

    current_user_is users(:f_student)
    assert_no_difference "Topic.count" do
      post :create, params: { forum_id: forum.id, topic: { title: "", body: "Desc." }}
    end
    assert_redirected_to forum_path(forum)
    assert_equal "There are some problems creating the conversation. Please try again.", flash[:error]
  end

  def test_program_forum_create
    user = users(:mkr_student)
    forum = forums(:forums_1)
    assert_false forum.subscribed_by?(user)
    forum.program.organization.security_setting.update_attribute(:sanitization_version, "v1")

    current_user_is user
    Topic.expects(:notify_subscribers).once
    assert_no_difference "VulnerableContentLog.count" do
      assert_difference "RecentActivity.count" do
        assert_difference "Subscription.count", 2 do
          assert_difference "Topic.count" do
            post :create, params: { forum_id: forum.id, topic: { title: "Topic 1", body: "<script>alert(10);</script>" }}
          end
        end
      end
    end
    topic = Topic.last

    assert_equal "A new conversation has been started successfully.", flash[:notice]

    assert forum.reload.subscribed_by?(user)
    assert topic.subscribed_by?(user)
    assert_equal "Topic 1", topic.title
    assert_equal "<script>alert(10);</script>", topic.body
    assert_equal user, topic.user
    assert_equal forum, topic.forum
  end

  ## GROUP FORUM: CREATE ##
  def test_group_forum_create_permission_denied
    group = groups(:mygroup)
    user = group.members.first
    forum = forums(:common_forum)
    forum.update_attribute(:group_id, group.id)
    assert_false group.forum_enabled?

    current_user_is user
    assert_permission_denied do
      post :create, params: { forum_id: forum.id, topic: { title: "Topic 1", body: "Desc." }}
    end
  end

  def test_group_forum_create_non_group_member
    group_forum_setup

    current_user_is users(:f_admin)
    assert_permission_denied do
      post :create, params: { forum_id: @forum.id, topic: { title: "Topic 1", body: "Desc." }}
    end
  end

  def test_group_forum_create
    group_forum_setup
    user = @group.members.first
    @forum.program.organization.security_setting.update_attribute(:sanitization_version, "v2")

    current_user_is user
    Topic.expects(:notify_subscribers).once
    assert_difference "VulnerableContentLog.count" do
      assert_no_difference "RecentActivity.count" do
        assert_difference "Subscription.count", @group.members.size do
          assert_difference "Topic.count" do
            post :create, params: { forum_id: @forum.id, topic: { title: "Topic 1", body: "desc<script>alert(10);</script>" }}
          end
        end
      end
    end
    topic = Topic.last
    assert_equal "A new conversation has been started successfully.", flash[:notice]

    assert @group.members.all? { |group_member| topic.subscribed_by?(group_member) }
    assert_equal "Topic 1", topic.title
    assert_equal "descalert(10);", topic.body
    assert_equal user, topic.user
    assert_equal @forum, topic.forum

    vulnerable_content_log = VulnerableContentLog.last
    assert_equal "desc<script>alert(10);</script>", vulnerable_content_log.original_content
    assert_equal "descalert(10);", vulnerable_content_log.sanitized_content
    assert_equal Topic.name, vulnerable_content_log.ref_obj_type
    assert_equal "body", vulnerable_content_log.ref_obj_column
  end

  def test_forum_create_homepage
    group_forum_setup
    user = @group.members.first
    @forum.program.organization.security_setting.update_attribute(:sanitization_version, "v2")

    current_user_is user
    Topic.expects(:notify_subscribers).once
    assert_no_difference "RecentActivity.count" do
      assert_difference "Subscription.count", @group.members.size do
        assert_difference "Topic.count" do
          post :create, xhr: true, params: { forum_id: @forum.id, topic: { title: "Topic 1", body: "post creation example" }}
          assert assigns(:group_id)
        end
      end
    end
  end

  ## PROGRAM FORUM: FOLLOW ##
  def test_program_forum_follow_permission_denied
    topic = create_topic(forum: forums(:forums_1))

    current_user_is users(:f_mentor)
    assert_permission_denied do
      post :follow, xhr: true, params: { id: topic.id, forum_id: topic.forum_id}
    end
  end

  def test_program_forum_follow_feature_disabled
    topic = create_topic(forum: forums(:forums_1))
    topic.program.enable_feature(FeatureName::FORUMS, false)

    current_user_is users(:f_student)
    assert_permission_denied do
      post :follow, xhr: true, params: { id: topic.id, forum_id: topic.forum_id}
    end
  end

  def test_program_forum_follow
    topic = create_topic(forum: forums(:forums_1))
    user = users(:f_student)
    assert_false topic.subscribed_by?(user)

    current_user_is user
    post :follow, xhr: true, params: { id: topic.id, forum_id: topic.forum_id, subscribe: "true"}
    assert_response :success
    assert topic.reload.subscribed_by?(user)
  end

  def test_program_forum_follow_reset
    topic = create_topic(forum: forums(:forums_1))
    user = topic.user
    assert topic.subscribed_by?(user)

    current_user_is user
    post :follow, xhr: true, params: { id: topic.id, forum_id: topic.forum_id}
    assert_response :success
    assert_false topic.reload.subscribed_by?(user)
  end

  ## GROUP FORUM: FOLLOW ##
  def test_group_forum_follow_permission_denied
    group = groups(:mygroup)
    user = group.members.first
    topic = create_topic(user: user)
    topic.forum.update_attribute(:group_id, group.id)
    assert_false group.forum_enabled?

    current_user_is user
    assert_permission_denied do
      post :follow, xhr: true, params: { id: topic.id, forum_id: topic.forum_id}
    end
  end

  def test_group_forum_follow_non_group_member
    group_forum_setup
    topic = create_topic(forum: @forum, user: @group.mentors.first)

    current_user_is users(:f_admin)
    assert_permission_denied do
      post :follow, xhr: true, params: { id: topic.id, forum_id: @forum.id}
    end
  end

  def test_group_forum_follow
    group_forum_setup
    user = @group.members.first
    topic = create_topic(forum: @forum, user: user)
    assert topic.subscribed_by?(user)

    current_user_is user
    post :follow, xhr: true, params: { id: topic.id, forum_id: topic.forum_id}
    assert_false topic.reload.subscribed_by?(user)
  end

  ## SET STICKY POSITION ##
  def test_set_sticky_position_permission_denied
    topic = create_topic

    current_user_is users(:f_mentor)
    assert_permission_denied do
      get :set_sticky_position, xhr: true, params: { id: topic.id, forum_id: topic.forum_id, sticky_position: "1"}
    end
  end

  def test_set_sticky_position_restricted_for_group_forum
    topic = create_topic
    topic.forum.update_attribute(:group_id, groups(:mygroup).id)

    current_user_is users(:f_admin)
    assert_permission_denied do
      get :set_sticky_position, xhr: true, params: { id: topic.id, forum_id: topic.forum_id, sticky_position: "1"}
    end
  end

  def test_set_sticky_position_feature_disabled
    topic = create_topic
    topic.program.enable_feature(FeatureName::FORUMS, false)

    current_user_is users(:f_admin)
    assert_permission_denied do
      get :set_sticky_position, xhr: true, params: { id: topic.id, forum_id: topic.forum_id, sticky_position: "1"}
    end
  end

  def test_set_sticky_position
    topic = create_topic
    assert_false topic.sticky?

    current_user_is users(:f_admin)
    get :set_sticky_position, xhr: true, params: { id: topic.id, forum_id: topic.forum_id, sticky_position: "1"}
    assert_response :success
    assert topic.reload.sticky?
  end

  def test_set_sticky_position_reset
    topic = create_topic(sticky_position: 1)
    assert topic.sticky?

    current_user_is users(:f_admin)
    get :set_sticky_position, xhr: true, params: { id: topic.id, forum_id: topic.forum_id, sticky_position: "0"}
    assert_response :success
    assert_false topic.reload.sticky?
  end

  ## PROGRAM FORUM: FETCH ALL COMMENTS ##
  def test_program_forum_fetch_all_comments_permission_denied
    topic = create_topic(forum: forums(:forums_1))
    post = create_post(topic: topic)

    current_user_is users(:f_mentor)
    assert_permission_denied do
      get :fetch_all_comments, xhr: true, params: { id: topic.id, forum_id: topic.forum_id, root_id: post.id}
    end
  end

  def test_program_forum_fetch_all_comments_feature_disabled
    topic = create_topic
    post = create_post(topic: topic)
    topic.program.enable_feature(FeatureName::FORUMS, false)

    current_user_is users(:f_admin)
    assert_permission_denied do
      get :fetch_all_comments, xhr: true, params: { id: topic.id, forum_id: topic.forum_id, root_id: post.id}
    end
  end

  def test_program_forum_fetch_all_comments
    topic = create_topic
    post = create_post(topic: topic)
    3.times { |i| create_post(topic: topic, ancestry: post.id, body: "Comment #{i}") }

    current_user_is users(:f_admin)
    get :fetch_all_comments, xhr: true, params: { id: topic.id, forum_id: topic.forum_id, root_id: post.id}
    assert_response :success
    assert_equal post, assigns(:root_post)

    response = JSON.parse(@response.body)
    assert_equal 2, response.keys.size
    3.times { |i| assert_match "Comment #{i}", response["content"] }
    assert_equal "<span>View all 3 comments</span>", response["view_all_comments_label"]
  end

  ## GROUP FORUM: FETCH ALL COMMENTS ##
    def test_group_forum_fetch_all_comments_permission_denied
    group = groups(:mygroup)
    user = group.members.first
    topic = create_topic(user: user)
    post = create_post(topic: topic, user: user)
    topic.forum.update_attribute(:group_id, group.id)
    assert_false group.forum_enabled?

    current_user_is user
    assert_permission_denied do
      get :fetch_all_comments, xhr: true, params: { id: topic.id, forum_id: topic.forum_id, root_id: post.id}
    end
  end

  def test_group_forum_fetch_all_comments_non_group_member
    group_forum_setup
    user = @group.members.first
    topic = create_topic(user: user, forum: @forum)
    post = create_post(topic: topic, user: user)

    current_user_is users(:f_student)
    assert_permission_denied do
      get :fetch_all_comments, xhr: true, params: { id: topic.id, forum_id: @forum.id, root_id: post.id}
    end
  end

  def test_group_forum_fetch_all_comments
    group_forum_setup
    mentor = @group.mentors.first
    student = @group.students.first
    topic = create_topic(forum: @forum, user: mentor)
    post = create_post(topic: topic, user: mentor)
    3.times { |i| create_post(topic: topic, user: student, ancestry: post.id, body: "Comment #{i}") }

    @controller.expects(:prepare_template).once
    @controller.expects(:update_login_count).once
    @controller.expects(:update_last_visited_tab).once
    current_user_is mentor
    get :fetch_all_comments, xhr: true, params: { id: topic.id, forum_id: @forum.id, root_id: post.id}
    assert_response :success

    content = JSON.parse(@response.body)["content"]
    3.times { |i| assert_match "Comment #{i}", content }
  end

  def test_group_forum_fetch_all_comments_admin_visit
    group_forum_setup
    user = @group.members.first
    topic = create_topic(user: user, forum: @forum)
    post = create_post(user: user, topic: topic)
    3.times { |i| create_post(topic: topic, user: user, ancestry: post.id, body: "Comment #{i}") }

    @controller.expects(:prepare_template).once
    @controller.expects(:update_login_count).once
    @controller.expects(:update_last_visited_tab).once
    current_user_is users(:f_admin)
    get :fetch_all_comments, xhr: true, params: { id: topic.id, forum_id: @forum.id, root_id: post.id}
    assert_response :success

    content = JSON.parse(@response.body)["content"]
    3.times { |i| assert_match "Comment #{i}", content }
  end

  ## PROGRAM FORUM: DESTROY ##
  def test_program_forum_destroy_permission_denied
    topic = create_topic
    current_user_is users(:f_mentor)
    assert_permission_denied do
      delete :destroy, params: { id: topic.id, forum_id: topic.forum_id}
    end
  end

  def test_program_forum_destroy_feature_disabled
    topic = create_topic
    topic.program.enable_feature(FeatureName::FORUMS, false)

    current_user_is topic.user
    assert_permission_denied do
      delete :destroy, params: { id: topic.id, forum_id: topic.forum_id}
    end
  end

  def test_program_forum_destroy
    topic = create_topic
    create_post(topic: topic)
    create_post(topic: topic)

    current_user_is topic.user
    assert_difference "Topic.count", -1 do
      assert_difference "Post.count", -2 do
        delete :destroy, params: { id: topic.id, forum_id: topic.forum_id}
      end
    end
    assert_redirected_to forum_path(topic.forum)
    assert_equal "The conversation has been removed.", flash[:notice]
  end

  def test_program_forum_admin_can_destroy
    topic = create_topic(user: users(:f_mentor))
    create_post(topic: topic)

    current_user_is users(:f_admin)
    assert_difference "Topic.count", -1 do
      assert_difference "Post.count", -1 do
        delete :destroy, params: { id: topic.id, forum_id: topic.forum_id}
      end
    end
    assert_redirected_to forum_path(topic.forum)
    assert_equal "The conversation has been removed.", flash[:notice]
  end

  ## GROUP FORUM: DESTROY ##
  def test_group_forum_destroy_permission_denied
    group = groups(:mygroup)
    user = group.members.first
    topic = create_topic(user: user)
    topic.forum.update_attribute(:group_id, group.id)
    assert_false group.forum_enabled?

    current_user_is user
    assert_permission_denied do
      delete :destroy, params: { id: topic.id, forum_id: topic.forum_id}
    end
  end

  def test_group_forum_destroy_non_group_member
    group_forum_setup
    topic = create_topic(forum: @forum, user: @group.members.first)

    current_user_is users(:f_admin)
    assert_permission_denied do
      delete :destroy, params: { id: topic.id, forum_id: @forum.id}
    end
  end

  def test_group_forum_destroy
    group_forum_setup
    user = @group.members.first
    topic = create_topic(forum: @forum, user: user)
    create_post(topic: topic, user: user)
    create_post(topic: topic, user: user)

    current_user_is user
    assert_difference "Topic.count", -1 do
      assert_difference "Post.count", -2 do
        delete :destroy, params: { id: topic.id, forum_id: @forum.id}
      end
    end
    assert_redirected_to forum_path(@forum)
    assert_equal "The conversation has been removed.", flash[:notice]
  end

  def test_mark_viewed
    current_user_is :mkr_student
    group = groups(:mygroup)
    group.mentoring_model = mentoring_models(:mentoring_models_1)
    group.mentoring_model.allow_forum = true
    group.save
    group.create_group_forum
    mentor = group.mentors.first
    student = group.students.first
    topic1 = create_topic(forum: group.forum, user: mentor)
    topic2 = create_topic(forum: group.forum, user: mentor)
    post1 = create_post(topic: topic1, user: mentor)
    post2 = create_post(topic: topic2, user: mentor)
    Group.any_instance.stubs(:forum_enabled?).returns(true)

    assert_difference "ViewedObject.count", 1 do
      get :mark_viewed, xhr: true, params: {id: topic1.id, forum_id: topic1.forum.id}
    end

    assert_equal 1, assigns(:unviewed_discussions_board_count)
    assert_false assigns(:home_page)

    assert_difference "ViewedObject.count", 1 do
      get :mark_viewed, xhr: true, params: {id: topic2.id, forum_id: topic2.forum.id, home_page: true}
    end

    assert_equal 0, assigns(:unviewed_discussions_board_count)
    assert assigns(:home_page)
  end
end