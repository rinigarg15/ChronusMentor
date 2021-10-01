require_relative './../test_helper.rb'

class PostTest < ActiveSupport::TestCase

  def test_forum_and_program
    program = programs(:ceg)
    user = users(:ceg_admin)
    forum = create_forum(program: program)
    topic = create_topic(forum: forum, user: user)
    post = create_post(topic: topic, user: user)
    assert_equal program, post.program
    assert_equal forum, post.forum
  end

  def test_ancestry
    topic = create_topic
    post_1 = create_post(topic: topic)
    assert_nil post_1.ancestry
    assert_equal post_1, post_1.root
    assert post_1.root?

    post_2 = create_post(topic: topic, ancestry: post_1.id)
    assert_equal post_1.id.to_s, post_2.ancestry
    assert_equal post_1, post_2.root
    assert_false post_2.root?
  end

  def test_has_many_ra_and_pending_notifications
    forum = forums(:forums_1)
    topic = create_topic(forum: forum)
    topic.subscribers.first.update_attribute(:program_notification_setting, UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY)

    post = nil
    assert_difference "RecentActivity.count", 1 do
      assert_difference "PendingNotification.count", 1 do
        post = create_post(topic: topic, user: users(:f_student))
      end
    end
    assert_equal 1, post.recent_activities.size
    assert_equal 1, post.pending_notifications.size

    assert_difference "RecentActivity.count", -1 do
      assert_difference "PendingNotification.count", -1 do
        post.destroy
      end
    end
  end

  def test_unpublished_and_published_scopes_for_posts
    topic = create_topic
    create_post(topic: topic)
    assert_equal 1, topic.reload.posts.published.size
    assert_equal 0, topic.posts.unpublished.size

    create_post(topic: topic, published: false)
    assert_equal 1, topic.reload.posts.published.size
    assert_equal 1, topic.posts.unpublished.size
  end

  def test_created_in_date_range
    topic = nil
    post = nil
    time_traveller(5.days.ago) do
      topic = create_topic
      post = create_post(topic: topic)
    end
    assert_empty topic.reload.posts.created_in_date_range(Time.now..5.days.from_now)
    assert_equal [post], topic.posts.created_in_date_range(6.days.ago..Time.now)
  end

  def test_validations
    e = assert_raise(ActiveRecord::RecordInvalid) do
      Post.create!
    end
    assert_match(/Topic can't be blank/, e.message)
    assert_match(/User can't be blank/, e.message)
    assert_match(/Message can't be blank/, e.message)
  end

  def test_check_for_user_permission_in_program_forum
    mentor_user = users(:f_mentor)
    topic = create_topic
    post = create_post(topic: topic, user: mentor_user)
    forum = post.forum

    forum.access_role_names = [RoleConstants::STUDENT_NAME]
    forum.save!
    assert_raise ActiveRecord::RecordInvalid do
      assert_no_difference "Post.count" do
        create_post(user: mentor_user, topic: topic)
      end
    end
    assert post.reload.valid?
  end

  def test_check_for_user_permission_in_group_forum
    Group.any_instance.stubs(:forum_enabled?).returns(true)
    group = groups(:mygroup)
    group_user = group.members.first
    forum = create_forum(group_id: group.id)
    topic = create_topic(forum: forum, user: group_user)
    admin_user = users(:f_admin)
    assert group.members.exclude?(admin_user)

    assert_difference "Post.count" do
      create_post(topic: topic, user: group_user)
    end

    assert_raise ActiveRecord::RecordInvalid do
      assert_no_difference "Post.count" do
        create_post(topic: topic, user: admin_user)
      end
    end
  end

  def test_check_moderation_and_flagging
    Group.any_instance.stubs(:forum_enabled?).returns(true)
    group = groups(:mygroup)
    group_mentor = group.mentors.first
    group_student = group.students.first
    forum = create_forum(group_id: group.id)
    topic = create_topic(forum: forum, user: group_mentor)

    e = assert_raise ActiveRecord::RecordInvalid do
      create_post(topic: topic, user: group_mentor, published: false)
    end
    assert_match(/Content moderation is disabled for discussion board./, e.message)

    post = create_post(topic: topic, user: group_mentor)
    post.flags.create!(user_id: group_student.id, program_id: group.program_id, reason: "Violation!", status: Flag::Status::UNRESOLVED)
    assert_false post.valid?
    assert_equal "Flagging is disabled for discussion board.", post.errors[:base][0]
  end

  def test_notify_admins_for_moderation
    topic = create_topic
    post = create_post(topic: topic)
    program = post.program
    admin_users = program.admin_users
    assert_not_empty program.admin_users

    assert_no_difference "JobLog.count" do
      assert_no_emails do
        Post.notify_admins_for_moderation(program, post, RecentActivityConstants::Type::POST_CREATION)
      end
    end

    post_2 = create_post(published: false, topic: topic)
    assert_difference "JobLog.count", admin_users.size do
      assert_emails admin_users.size do
        Post.notify_admins_for_moderation(program, post_2, RecentActivityConstants::Type::POST_CREATION)
      end
    end

    assert_no_difference "JobLog.count", admin_users.size do
      assert_no_emails do
        Post.notify_admins_for_moderation(program, post_2, RecentActivityConstants::Type::POST_CREATION)
      end
    end
  end

  def test_can_be_deleted_for_program_forum
    admin_user = users(:f_admin)
    non_admin_user = users(:f_mentor)
    non_admin_user_2 = users(:f_student)
    topic = create_topic
    post = create_post(published: false, user: non_admin_user, topic: topic)

    assert post.can_be_deleted?(admin_user)
    assert_false post.can_be_deleted?(non_admin_user)
    assert_false post.can_be_deleted?(non_admin_user_2)

    post.update_attributes(published: true)
    assert post.can_be_deleted?(admin_user)
    assert post.can_be_deleted?(non_admin_user)
    assert_false post.can_be_deleted?(non_admin_user_2)
  end

  def test_can_be_deleted_for_group_forum
    Group.any_instance.stubs(:forum_enabled?).returns(true)
    group = groups(:mygroup)
    forum = create_forum(group_id: group.id)
    group_mentor = group.mentors.first
    group_student = group.students.first
    admin_user = users(:f_admin)

    topic = create_topic(forum: forum, user: group_mentor)
    post = create_post(topic: topic, user: group_mentor)
    assert post.can_be_deleted?(group_mentor)
    assert_false post.can_be_deleted?(group_student)
    assert_false post.can_be_deleted?(admin_user)
  end

  def test_create_post_with_attachment
    topic = create_topic
    post = Post.new(body: 'hello', attachment: fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'))
    post.user = users(:f_admin)
    post.topic = topic
    post.save!
    assert_equal 'test_pic.png', post.attachment_file_name
  end

  def test_create_post_attachment_size_violated
    topic = create_topic
    post = Post.new(body: 'hello', attachment_file_name: 'some_file.pdf', attachment_file_size: 21.megabytes)
    post.user = users(:f_admin)
    post.topic = topic
    assert_false post.valid?
    assert_equal ["should be within 20 MB"], post.errors[:attachment_file_size]
  end

  def test_create_post_attachment_extension_violated
    topic = create_topic
    post = Post.new(body: 'hello', attachment_file_name: 'some_file.asp', attachment_file_size: 1.megabytes)
    post.user = users(:f_admin)
    post.topic = topic
    assert_false post.valid?
    assert_equal ["is invalid"], post.errors[:attachment_file_name]
  end

  def test_create_post_attachment_type_violated
    topic = create_topic
    post = Post.new(body: 'hello', attachment: fixture_file_upload(File.join("files", "test_php.php"), "application/x-php"))
    post.user = users(:f_admin)
    post.topic = topic
    assert_false post.valid?
    assert_equal ["is invalid"], post.errors[:attachment_file_name]
    assert_equal ["is restricted"], post.errors[:attachment_content_type]
  end

  def test_fetch_children_and_unmoderated_children_count
    admin_user = users(:f_admin)
    mentor_user = users(:f_mentor)

    topic = create_topic
    post = create_post(topic: topic)
    child_1 = create_post(topic: topic, published: false, user: mentor_user, ancestry: post.id)
    child_2 = create_post(topic: topic, user: mentor_user, ancestry: post.id)
    child_3 = create_post(topic: topic, user: mentor_user, ancestry: post.id)
    create_post(topic: topic, user: mentor_user)

    output = post.fetch_children_and_unmoderated_children_count(admin_user)
    assert_equal 2, output.size
    assert_equal [child_1, child_2, child_3], output[0]
    assert_equal 1, output[1]
    output = post.fetch_children_and_unmoderated_children_count(mentor_user)
    assert_equal 2, output.size
    assert_equal [child_2, child_3], output[0]
    assert_equal 0, output[1]

    child_1.update_attribute(:published, true)
    output = post.fetch_children_and_unmoderated_children_count(admin_user)
    assert_equal 2, output.size
    assert_equal [child_1, child_2, child_3], output[0]
    assert_equal 0, output[1]
    output = post.fetch_children_and_unmoderated_children_count(mentor_user)
    assert_equal 2, output.size
    assert_equal [child_1, child_2, child_3], output[0]
    assert_equal 0, output[1]
  end

  def test_recent_activity_type
    assert_equal RecentActivityConstants::Type::POST_CREATION, Post.recent_activity_type
  end

  def test_push_notification_type
    assert_equal PushNotification::Type::FORUM_POST_CREATED, Post.push_notification_type
  end

  def test_es_reindex
    group = groups(:group_pbe_4)
    forum = group.forum
    user = group.members.first
    topic = create_topic(forum: forum, user: user)
    post = create_post(topic: topic, user: user)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Topic, [topic.id])
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Group, [group.id])
    Post.es_reindex(post)
  end

  def test_reindex_group
    group = groups(:group_pbe_4)
    forum = group.forum
    user = group.members.first
    topic = create_topic(forum: forum, user: user)
    post = create_post(topic: topic, user: user)

    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Group, [group.id])
    Post.reindex_group([group.id])
  end

  def test_notification_list
    mentor_1 = users(:mentor_8)
    mentor_2 = users(:mentor_9)
    student_1 = users(:student_8)
    student_2 = users(:student_9)
    users = [mentor_1, mentor_2, student_1, student_2]

    topic = create_topic(user: mentor_1)
    post = create_post(topic: topic, user: mentor_1)
    assert topic.subscribed_by?(mentor_1)
    assert_empty post.notification_list

    topic.subscribe_user(mentor_2)
    topic.subscribe_user(student_1)
    topic.subscribe_user(student_2)
    assert_equal_unordered [mentor_2, student_1, student_2], post.notification_list

    fetch_role(:albers, RoleConstants::MENTOR_NAME).remove_permission("view_students")
    users.collect(&:reload)
    assert_equal_unordered [mentor_2, student_1, student_2], post.notification_list

    fetch_role(:albers, RoleConstants::STUDENT_NAME).remove_permission("view_mentors")
    users.collect(&:reload)
    assert_equal [mentor_2], post.notification_list
  end
end