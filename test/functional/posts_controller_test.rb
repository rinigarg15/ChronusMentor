require_relative './../test_helper.rb'

class PostsControllerTest < ActionController::TestCase

  ## INDEX ##
  def test_index
    topic = create_topic

    current_user_is users(:f_admin)
    get :index, params: { topic_id: topic.id, forum_id: topic.forum_id}
    assert_redirected_to forum_topic_path(topic.forum, topic)
  end

  ## PROGRAM FORUM: CREATE ##
  def test_program_forum_create_permission_denied
    topic = create_topic(forum: forums(:forums_1))

    current_user_is users(:f_mentor)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::POST_TO_FORUM, {context_object: topic.forum.name}).never
    assert_permission_denied do
      post :create, xhr: true, params: { topic_id: topic.id, forum_id: topic.forum_id, post: { body: "Desc." }}
    end
  end

  def test_program_forum_create_feature_disabled
    topic = create_topic(forum: forums(:forums_1))
    programs(:albers).enable_feature(FeatureName::FORUMS, false)

    current_user_is users(:f_student)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::POST_TO_FORUM, {context_object: topic.forum.name}).never
    assert_permission_denied do
      post :create, xhr: true, params: { topic_id: topic.id, forum_id: topic.forum_id, post: { body: "Desc." }}
    end
  end

  def test_program_forum_create_invalid_params
    topic = create_topic(forum: forums(:forums_1))

    current_user_is users(:f_student)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::POST_TO_FORUM, {context_object: topic.forum.name}).never
    assert_no_difference "Post.count" do
      post :create, xhr: true, params: { topic_id: topic.id, forum_id: topic.forum_id, post: { body: "" }}
    end
    assert_response :success
    assert_equal "Message can't be blank", assigns(:error_message)
  end

  def test_program_forum_create_invalid_attachment
    topic = create_topic(forum: forums(:forums_1))

    current_user_is users(:f_student)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::POST_TO_FORUM, {context_object: topic.forum.name}).never
    assert_no_difference "Post.count" do
      post :create, xhr: true, params: { topic_id: topic.id, forum_id: topic.forum_id, post: { body: "Desc.", attachment: fixture_file_upload(File.join("files", "test_php.php"), "application/x-php") }}
    end
    assert_response :success
    assert_equal "Attachment content type is restricted and Attachment file name is invalid", assigns(:error_message)
  end

  def test_program_forum_create_virus_error
    topic = create_topic(forum: forums(:forums_1))

    Post.any_instance.expects(:save).at_least(1).raises(VirusError)
    current_user_is users(:f_student)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::POST_TO_FORUM, {context_object: topic.forum.name}).never
    assert_no_difference "Post.count" do
      post :create, xhr: true, params: { topic_id: topic.id, forum_id: topic.forum_id, post: { body: "Desc.", attachment: fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png') }}
    end
    assert_response :success
    assert_equal "Our security system has detected the presence of a virus in the attachment.", assigns(:error_message)
  end

  def test_program_forum_create_root
    user = users(:mkr_student)
    forum = forums(:forums_1)
    topic = create_topic(forum: forum)
    assert_false forum.subscribed_by?(user)
    assert_false topic.subscribed_by?(user)

    PostObserver.expects(:send_emails).once
    Post.expects(:notify_admins_for_moderation).never
    current_user_is user
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::POST_TO_FORUM, {context_object: topic.forum.name}).once
    assert_difference "RecentActivity.count" do
      assert_difference "Subscription.count", 2 do
        assert_difference "Post.count" do
          post :create, xhr: true, params: { topic_id: topic.id, forum_id: forum.id, post: { body: "Desc 1.", attachment: fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png') }}
        end
      end
    end
    post = Post.last
    assert_response :success
    assert_equal "Your post is created.", assigns(:success_message)
    assert_equal [post], assigns(:posts)

    assert forum.reload.subscribed_by?(user)
    assert topic.reload.subscribed_by?(user)
    assert post.published?
    assert_nil post.ancestry
    assert_equal "Desc 1.", post.body
    assert_equal user, post.user
    assert_equal topic, post.topic
  end

  def test_program_forum_create_root_unpublished
    user = users(:mkr_student)
    forum = forums(:forums_1)
    topic = create_topic(forum: forum)
    assert_false forum.subscribed_by?(user)
    assert_false topic.subscribed_by?(user)

    PostObserver.expects(:send_emails).never
    Forum.any_instance.expects(:allow_moderation?).returns(true)
    Post.expects(:notify_admins_for_moderation).once
    current_user_is user
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::POST_TO_FORUM, {context_object: topic.forum.name}).once
    assert_no_difference "RecentActivity.count" do
      assert_difference "Subscription.count", 2 do
        assert_difference "Post.count" do
          post :create, xhr: true, params: { topic_id: topic.id, forum_id: forum.id, post: { body: "Desc 1." }}
        end
      end
    end
    assert_response :success
    assert_equal "Thank you for your message. Your post will be uploaded to the forum shortly.", assigns(:success_message)
    assert_empty assigns(:posts)

    post = Post.last
    assert forum.reload.subscribed_by?(user)
    assert topic.reload.subscribed_by?(user)
    assert_false post.published?
    assert_nil post.ancestry
    assert_equal "Desc 1.", post.body
    assert_equal user, post.user
    assert_equal topic, post.topic
  end

  def test_program_forum_create_comment
    user = users(:mkr_student)
    forum = forums(:forums_1)
    topic = create_topic(forum: forum)
    root_post = create_post(topic: topic)
    assert_false forum.subscribed_by?(user)
    assert_false topic.subscribed_by?(user)

    PostObserver.expects(:send_emails).once
    Post.expects(:notify_admins_for_moderation).never
    current_user_is user
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::POST_TO_FORUM, {context_object: topic.forum.name}).once
    assert_difference "RecentActivity.count" do
      assert_difference "Subscription.count", 2 do
        assert_difference "Post.count" do
          post :create, xhr: true, params: { topic_id: topic.id, forum_id: forum.id, post: { body: "Desc 1.", parent_id: root_post.id }}
        end
      end
    end
    assert_response :success
    assert_equal "Your post is created.", assigns(:success_message)
    assert_nil assigns(:posts)

    post = Post.last
    assert forum.reload.subscribed_by?(user)
    assert topic.reload.subscribed_by?(user)
    assert post.published?
    assert_equal root_post.id.to_s, post.ancestry
    assert_equal "Desc 1.", post.body
    assert_equal user, post.user
    assert_equal topic, post.topic
  end

  def test_program_forum_create_comment_unpublished
    user = users(:mkr_student)
    forum = forums(:forums_1)
    topic = create_topic(forum: forum)
    root_post = create_post(topic: topic)
    assert_false forum.subscribed_by?(user)
    assert_false topic.subscribed_by?(user)

    PostObserver.expects(:send_emails).never
    Forum.any_instance.expects(:allow_moderation?).returns(true)
    Post.expects(:notify_admins_for_moderation).once
    current_user_is user
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::POST_TO_FORUM, {context_object: topic.forum.name}).once
    assert_no_difference "RecentActivity.count" do
      assert_difference "Subscription.count", 2 do
        assert_difference "Post.count" do
          post :create, xhr: true, params: { topic_id: topic.id, forum_id: forum.id, post: { body: "Desc 1.", parent_id: root_post.id }}
        end
      end
    end
    assert_response :success
    assert_equal "Thank you for your message. Your post will be uploaded to the forum shortly.", assigns(:success_message)
    assert_nil assigns(:posts)

    post = Post.last
    assert forum.reload.subscribed_by?(user)
    assert topic.reload.subscribed_by?(user)
    assert_false post.published?
    assert_equal root_post.id.to_s, post.ancestry
    assert_equal "Desc 1.", post.body
    assert_equal user, post.user
    assert_equal topic, post.topic
  end

  ## GROUP FORUM: CREATE ##
  def test_group_forum_create_permission_denied
    group = groups(:mygroup)
    user = group.members.first
    topic = create_topic(user: user)
    topic.forum.update_attribute(:group_id, group.id)
    assert_false group.forum_enabled?

    current_user_is user
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::POST_TO_FORUM, {context_object: group.name}).never
    assert_permission_denied do
      post :create, xhr: true, params: { topic_id: topic.id, forum_id: topic.forum_id, post: { body: "Desc 1." }}
    end
  end

  def test_group_forum_create_non_group_member
    group_forum_setup
    user = @group.members.first
    topic = create_topic(forum: @forum, user: user)

    current_user_is users(:f_admin)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::POST_TO_FORUM, {context_object: @group.name}).never
    assert_permission_denied do
      post :create, xhr: true, params: { topic_id: topic.id, forum_id: @forum.id, post: { body: "Desc 1." }}
    end
  end

  def test_group_forum_create
    group_forum_setup
    user = @group.members.first
    topic = create_topic(forum: @forum, user: user)
    topic.unsubscribe_user(user)
    @forum.unsubscribe_user(user)

    PostObserver.expects(:send_emails).once
    Post.expects(:notify_admins_for_moderation).never
    current_user_is user
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::POST_TO_FORUM, {context_object: @group.name}).once
    assert_no_difference "RecentActivity.count" do
      assert_difference "Subscription.count", 2 do
        assert_difference "Post.count" do
          post :create, xhr: true, params: { topic_id: topic.id, forum_id: @forum.id, post: { body: "Desc 1." }}
        end
      end
    end
    post = Post.last
    assert_response :success
    assert_equal "Your post is created.", assigns(:success_message)
    assert_equal [post], assigns(:posts)

    assert @forum.reload.subscribed_by?(user)
    assert topic.reload.subscribed_by?(user)
    assert post.published?
    assert_nil post.ancestry
    assert_equal "Desc 1.", post.body
    assert_equal user, post.user
    assert_equal topic, post.topic
  end

  ## PROGRAM FORUM: DESTROY ##
  def test_program_forum_destroy_permission_denied
    topic = create_topic(forum: forums(:forums_1))
    post = create_post(topic: topic)

    current_user_is users(:f_mentor)
    assert_permission_denied do
      delete :destroy, xhr: true, params: { id: post.id, topic_id: topic.id, forum_id: topic.forum_id}
    end
  end

  def test_program_forum_destroy_feature_disabled
    topic = create_topic(forum: forums(:forums_1))
    post = create_post(topic: topic)
    topic.program.enable_feature(FeatureName::FORUMS, false)

    current_user_is post.user
    assert_permission_denied do
      delete :destroy, xhr: true, params: { id: post.id, topic_id: topic.id, forum_id: topic.forum_id}
    end
  end

  def test_program_forum_destroy
    topic = create_topic(forum: forums(:forums_1))
    post = create_post(topic: topic)
    flag = create_flag(content: post)
    assert_equal Flag::Status::UNRESOLVED, flag.status

    ChronusMailer.expects(:content_moderation_user_notification).never
    current_user_is post.user
    assert_difference "Post.count", -1 do
      delete :destroy, xhr: true, params: { id: post.id, topic_id: topic.id, forum_id: topic.forum_id}
    end
    assert_response :success
    assert_equal "Post has been deleted", assigns[:success_message]
    assert_empty assigns[:posts]
    assert_equal Flag::Status::DELETED, flag.reload.status
  end

  def test_program_forum_admin_can_destroy_unpublished_post
    topic = create_topic(forum: forums(:forums_1))
    post = create_post(topic: topic, user: users(:f_student), published: false)

    ChronusMailer.expects(:content_moderation_user_notification).with(post.user, post, "Offensive!").returns(stub(:deliver_now))
    current_user_is users(:f_admin)
    assert_difference "Post.count", -1 do
      delete :destroy, params: { id: post.id, topic_id: topic.id, forum_id: topic.forum_id, reason: "Offensive!", from_moderate_content: false}
    end
    assert_redirected_to forum_topic_path(topic.forum, topic, from_moderate_content: false)
    assert_equal "The post was not published.", flash[:notice]
    assert_nil assigns(:posts)
  end

  def test_program_forum_admin_can_destroy_unpublished_post_from_moderatable_posts
    topic = create_topic(forum: forums(:forums_1))
    post = create_post(topic: topic, user: users(:f_student), published: false)

    ChronusMailer.expects(:content_moderation_user_notification).with(post.user, post, "Offensive!").returns(stub(:deliver_now))
    current_user_is users(:f_admin)
    assert_difference "Post.count", -1 do
      delete :destroy, params: { id: post.id, topic_id: topic.id, forum_id: topic.forum_id, reason: "Offensive!", redirect_back_to: forums_path(root: topic.program.root)}
    end
    assert_redirected_to forums_path
    assert_equal "The post was not published.", flash[:notice]
    assert_nil assigns(:posts)
  end

  def test_program_forum_post_user_cannot_destroy_when_unpublished
    topic = create_topic(forum: forums(:forums_1))
    post = create_post(topic: topic, user: users(:f_student), published: false)

    current_user_is post.user
    assert_permission_denied do
      delete :destroy, params: { id: post.id, topic_id: topic.id, forum_id: topic.forum_id, reason: "Offensive!"}
    end
  end

  ## GROUP FORUM: DESTROY ##
  def test_group_forum_destroy_permission_denied
    group = groups(:mygroup)
    user = group.members.first
    topic = create_topic(user: user)
    post = create_post(topic: topic, user: user)
    post.forum.update_attribute(:group_id, group.id)
    assert_false group.forum_enabled?

    current_user_is user
    assert_permission_denied do
      delete :destroy, xhr: true, params: { id: post.id, topic_id: topic.id, forum_id: topic.forum_id}
    end
  end

  def test_group_forum_destroy_non_group_member
    group_forum_setup
    user = @group.members.first
    topic = create_topic(forum: @forum, user: user)
    post = create_post(topic: topic, user: user)

    current_user_is users(:f_admin)

    assert_permission_denied do
      delete :destroy, xhr: true, params: { id: post.id, topic_id: topic.id, forum_id: @forum.id}
    end
  end

  def test_group_forum_destroy
    group_forum_setup
    user = @group.members.first
    topic = create_topic(forum: @forum, user: user)
    post = create_post(topic: topic, user: user)

    ChronusMailer.expects(:content_moderation_user_notification).never
    current_user_is user
    assert_difference "Post.count", -1 do
      delete :destroy, xhr: true, params: { id: post.id, topic_id: topic.id, forum_id: @forum.id}
    end
    assert_response :success
    assert_equal "Post has been deleted", assigns[:success_message]
    assert_empty assigns(:posts)
  end

  ## MODERATABLE_POSTS ##
  def test_moderatable_posts_permission_denied
    programs(:albers).enable_feature(FeatureName::MODERATE_FORUMS)

    current_user_is :f_mentor
    assert_permission_denied do
      get :moderatable_posts
    end
  end

  def test_moderatable_posts_feature_disabled
    programs(:albers).enable_feature(FeatureName::MODERATE_FORUMS)
    programs(:albers).enable_feature(FeatureName::FORUMS, false)

    current_user_is users(:f_admin)
    assert_permission_denied do
      get :moderatable_posts
    end
  end

  def test_moderatable_posts_moderation_disabled
    assert_false programs(:albers).moderation_enabled?

    current_user_is users(:f_admin)
    assert_permission_denied do
      get :moderatable_posts
    end
  end

  def test_moderatable_posts
    programs(:albers).enable_feature(FeatureName::MODERATE_FORUMS)
    topic = create_topic
    create_post(topic: topic) # published posts are ignored
    unpublished_posts = 11.times.collect { create_post(topic: topic, published: false) }

    current_user_is users(:f_admin)
    get :moderatable_posts
    assert_response :success
    assert_equal unpublished_posts[0..9], assigns(:unpublished_posts)

    get :moderatable_posts, params: { page: 2}
    assert_response :success
    assert_equal [unpublished_posts[10]], assigns(:unpublished_posts)
  end

  ## MODERATE_PUBLISH ##
  def test_moderate_publish_permission_denied
    topic = create_topic
    post_1 = create_post(topic: topic, published: false)

    current_user_is users(:f_mentor)
    assert_permission_denied do
      post :moderate_publish, params: { id: post_1.id, topic_id: topic.id, forum_id: topic.forum_id}
    end
  end

  def test_moderate_publish_feature_disabled
    topic = create_topic
    post_1 = create_post(topic: topic, published: false)
    post_1.program.enable_feature(FeatureName::FORUMS, false)

    current_user_is users(:f_admin)
    assert_permission_denied do
      post :moderate_publish, params: { id: post_1.id, topic_id: topic.id, forum_id: topic.forum_id}
    end
  end

  def test_moderate_publish_restricted_for_group_forum
    topic = create_topic
    post_1 = create_post(topic: topic, published: false)
    topic.forum.update_attribute(:group_id, groups(:mygroup).id)

    current_user_is users(:f_admin)
    assert_permission_denied do
      post :moderate_publish, params: { id: post_1.id, topic_id: topic.id, forum_id: topic.forum_id}
    end
  end

  def test_moderate_publish
    user = users(:f_mentor)
    topic = create_topic
    post_1 = create_post(topic: topic, published: false, user: user)

    PostObserver.expects(:send_emails).with(post_1.id).once
    current_user_is users(:f_admin)
    assert_no_difference "Subscription.count" do
      assert_difference "RecentActivity.count", 1 do
        post :moderate_publish, params: { id: post_1.id, topic_id: topic.id, forum_id: topic.forum.id, redirect_back_to: forums_path(root: user.program.root)}
      end
    end
    assert_redirected_to forums_path
    assert_equal "Post by #{user.name} is published.", flash[:notice]
    assert post_1.reload.published?
  end

  ## MODERATE_DECLINE ##
  def test_moderate_decline_permission_denied
    topic = create_topic
    post = create_post(topic: topic, published: false)

    current_user_is users(:f_mentor)
    assert_permission_denied do
      get :moderate_decline, params: { id: post.id, topic_id: topic.id, forum_id: topic.forum_id}
    end
  end

  def test_moderate_decline_feature_disabled
    topic = create_topic
    post = create_post(topic: topic, published: false)
    post.program.enable_feature(FeatureName::FORUMS, false)

    current_user_is users(:f_admin)
    assert_permission_denied do
      get :moderate_decline, params: { id: post.id, topic_id: topic.id, forum_id: topic.forum_id}
    end
  end

  def test_moderate_decline_restricted_for_group_forum
    topic = create_topic
    post = create_post(topic: topic, published: false)
    topic.forum.update_attribute(:group_id, groups(:mygroup).id)

    current_user_is users(:f_admin)
    assert_permission_denied do
      get :moderate_decline, params: { id: post.id, topic_id: topic.id, forum_id: topic.forum_id}
    end
  end

  def test_moderate_decline
    user = users(:f_mentor)
    topic = create_topic
    post = create_post(topic: topic, published: false, user: user)

    current_user_is users(:f_admin)
    get :moderate_decline, params: { id: post.id, topic_id: topic.id, forum_id: topic.forum.id}
    assert_response :success
  end
end