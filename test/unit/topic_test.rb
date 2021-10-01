require_relative './../test_helper.rb'

class TopicTest < ActiveSupport::TestCase

  def test_program
    program = programs(:ceg)
    forum = create_forum(program: program)
    topic = create_topic(forum: forum, user: users(:ceg_admin))
    assert_equal program, topic.program
  end

  def test_subscription
    topic = create_topic
    topic_user = topic.user
    assert topic.subscribed_by?(topic_user)

    assert_difference "Subscription.count", -1 do
      topic.unsubscribe_user(topic_user)
    end
    assert_false topic.subscribed_by?(topic_user)

    assert_difference "Subscription.count" do
      topic.subscribe_user(topic_user)
    end
    assert topic.subscribed_by?(topic_user)
  end

  def test_has_many_posts
    topic = create_topic
    assert_difference "Post.count", 1 do
      create_post(topic: topic)
    end
    assert_difference "Post.count", -1 do
      topic.destroy
    end
  end

  def test_recent_post
    topic = create_topic
    post_1 = create_post(topic: topic)
    assert_equal post_1, topic.reload.recent_post

    post_2 = create_post(topic: topic)
    assert_equal post_2, topic.reload.recent_post

    post_2.destroy
    assert_equal post_1, topic.reload.recent_post
  end

  def test_has_many_ra_and_pending_notifications
    forum = forums(:forums_1)
    forum.subscribers.first.update_attribute(:program_notification_setting, UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY)

    topic = nil
    assert_difference "RecentActivity.count", 1 do
      assert_difference "PendingNotification.count", 1 do
        topic = create_topic(forum: forum, user: users(:f_student))
      end
    end
    assert_equal 1, topic.recent_activities.size
    assert_equal 1, topic.pending_notifications.size

    assert_difference "RecentActivity.count", -1 do
      assert_difference "PendingNotification.count", -1 do
        topic.destroy
      end
    end
  end

  def test_validations
    e = assert_raise(ActiveRecord::RecordInvalid) do
      Topic.create!
    end
    assert_match(/Forum can't be blank/, e.message)
    assert_match(/User can't be blank/, e.message)
    assert_match(/Title can't be blank/, e.message)
    assert_match(/Body can't be blank/, e.message)
  end

  def test_check_for_user_permission_in_program_forum
    mentor_user = users(:f_mentor)
    topic = create_topic(user: mentor_user)
    forum = topic.forum

    forum.access_role_names = [RoleConstants::STUDENT_NAME]
    forum.save!
    assert_raise ActiveRecord::RecordInvalid do
      assert_no_difference "Topic.count" do
        create_topic(user: mentor_user)
      end
    end
    assert topic.reload.valid?
  end

  def test_check_for_user_permission_in_group_forum
    group = groups(:mygroup)
    forum = create_forum(group_id: group.id)
    group_user = group.members.first
    admin_user = users(:f_admin)
    assert group.members.exclude?(admin_user)

    Group.any_instance.stubs(:forum_enabled?).returns(true)
    assert_difference "Topic.count" do
      create_topic(forum: forum, user: group_user)
    end

    assert_raise ActiveRecord::RecordInvalid do
      assert_no_difference "Topic.count" do
        create_topic(forum: forum, user: admin_user)
      end
    end
  end

  def test_hit
    topic = create_topic
    assert_equal 0, topic.hits

    topic.hit!
    assert_equal 1, topic.reload.hits
  end

  def test_replied_at_and_posts_count
    admin_user = users(:f_admin)
    non_admin_user = users(:f_mentor)

    topic = create_topic
    assert_nil topic.replied_at(admin_user)
    assert_nil topic.replied_at(non_admin_user)
    assert_equal 0, topic.get_posts_count(admin_user)
    assert_equal 0, topic.get_posts_count(non_admin_user)

    post_1 = create_post(topic: topic)
    post_2 = create_post(topic: topic, published: false)
    assert_equal 2, topic.reload.posts_count
    assert_equal post_2.updated_at.to_i, topic.replied_at(admin_user).to_i
    assert_equal post_1.updated_at.to_i, topic.replied_at(non_admin_user).to_i
    assert_equal 2, topic.get_posts_count(admin_user)
    assert_equal 1, topic.get_posts_count(non_admin_user)

    post_2.update_attributes(published: true)
    assert_equal 2, topic.reload.posts_count
    assert_equal post_2.updated_at.to_i, topic.replied_at(admin_user).to_i
    assert_equal post_2.updated_at.to_i, topic.replied_at(non_admin_user).to_i
    assert_equal 2, topic.get_posts_count(admin_user)
    assert_equal 2, topic.get_posts_count(non_admin_user)
  end

  def test_notify_subscribers_for_program_forum
    mentor_1 = users(:mentor_8)
    mentor_2 = users(:mentor_9)
    student_1 = users(:student_8)
    forum = create_forum(access_role_names: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    topic = nil

    Push::Base.expects(:queued_notify).never
    assert_no_difference "JobLog.count" do
      assert_no_emails do
        create_topic(forum: forum, user: mentor_1)
      end
    end

    forum.subscribe_user(mentor_1)
    forum.subscribe_user(mentor_2)
    forum.subscribe_user(student_1)
    fetch_role(:albers, RoleConstants::STUDENT_NAME).remove_permission("view_mentors")
    Push::Base.expects(:queued_notify).once
    assert_difference "JobLog.count" do
      assert_emails do
        topic = create_topic(forum: forum, user: mentor_2)
      end
    end
    assert_equal [mentor_1.email], ActionMailer::Base.deliveries.last.to
    assert_equal topic, JobLog.last.loggable_object

    Push::Base.expects(:queued_notify).never
    assert_no_difference "JobLog.count" do
      assert_no_emails do
        Topic.notify_subscribers(topic.id)
      end
    end

    assert_difference "JobLog.count", -1 do
      topic.destroy
    end
  end

  def test_notify_subscribers_for_group_forum
    group = groups(:mygroup)
    group_mentor = group.mentors.first
    group_student = group.students.first
    forum = create_forum(group_id: group.id)
    topic = nil

    Group.any_instance.stubs(:forum_enabled?).returns(true)
    Push::Base.expects(:queued_notify).never
    assert_no_difference "JobLog.count" do
      assert_no_emails do
        create_topic(forum: forum, user: group_mentor)
      end
    end

    forum.subscribe_user(group_mentor)
    forum.subscribe_user(group_student)
    Push::Base.expects(:queued_notify).once
    assert_difference "JobLog.count" do
      assert_emails do
        topic = create_topic(forum: forum, user: group_mentor)
      end
    end
    assert_equal [group_student.email], ActionMailer::Base.deliveries.last.to

    Push::Base.expects(:queued_notify).never
    assert_no_difference "JobLog.count" do
      assert_no_emails do
        Topic.notify_subscribers(topic.id)
      end
    end
  end

  def test_sticky
    topic = create_topic
    assert_equal 0, topic.sticky_position
    assert_false topic.sticky?

    topic.update_attribute(:sticky_position, 1)
    assert_equal 1, topic.sticky_position
    assert topic.sticky?
  end

  def test_can_be_deleted_for_program_forum
    forum = forums(:common_forum)
    admin_user = users(:f_admin)
    student_user = users(:f_student)
    student_user_2 = users(:mkr_student)
    mentor_user = users(:f_mentor)

    forum.access_role_names = [RoleConstants::STUDENT_NAME]
    forum.save!
    topic = create_topic(user: student_user)
    assert topic.can_be_deleted?(admin_user)
    assert topic.can_be_deleted?(student_user)
    assert_false topic.can_be_deleted?(student_user_2)
    assert_false topic.can_be_deleted?(mentor_user)
  end

  def test_can_be_deleted_for_group_forum
    group = groups(:mygroup)
    forum = create_forum(group_id: group.id)
    group_mentor = group.mentors.first
    group_student = group.students.first
    admin_user = users(:f_admin)

    Group.any_instance.stubs(:forum_enabled?).returns(true)
    topic = create_topic(forum: forum, user: group_mentor)
    assert topic.can_be_deleted?(group_mentor)
    assert_false topic.can_be_deleted?(group_student)
    assert_false topic.can_be_deleted?(admin_user)
  end

  def test_recent_activity_type
    assert_equal RecentActivityConstants::Type::TOPIC_CREATION, Topic.recent_activity_type
  end

  def test_push_notification_type
    assert_equal PushNotification::Type::FORUM_TOPIC_CREATED, Topic.push_notification_type
  end

  def test_notification_list
    forum = create_forum(access_role_names: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    mentor_1 = users(:mentor_8)
    mentor_2 = users(:mentor_9)
    student_1 = users(:student_8)
    student_2 = users(:student_9)
    users = [mentor_1, mentor_2, student_1, student_2]

    topic = create_topic(forum: forum, user: mentor_1)
    assert forum.subscribed_by?(mentor_1)
    assert_empty topic.notification_list

    forum.subscribe_user(mentor_2)
    forum.subscribe_user(student_1)
    forum.subscribe_user(student_2)
    assert_equal_unordered [mentor_2, student_1, student_2], topic.notification_list

    fetch_role(:albers, RoleConstants::MENTOR_NAME).remove_permission("view_students")
    users.collect(&:reload)
    assert_equal_unordered [mentor_2, student_1, student_2], topic.notification_list

    fetch_role(:albers, RoleConstants::STUDENT_NAME).remove_permission("view_mentors")
    users.collect(&:reload)
    assert_equal [mentor_2], topic.notification_list
  end

  def test_viewed_objects_association
    group = groups(:mygroup)
    group.create_group_forum
    mentor = group.mentors.first
    student = group.students.first
    topic1 = create_topic(forum: group.forum, user: mentor)
    post1 = create_post(topic: topic1, user: mentor)
    new_viewed_object = create_viewed_object(ref_obj: post1, user: student)
    assert_equal [new_viewed_object], post1.viewed_objects
    assert_difference "ViewedObject.count", -1 do
      post1.destroy
    end
  end

  def test_mark_posts_viewability_for_user
    group = groups(:mygroup)
    group.mentoring_model = mentoring_models(:mentoring_models_1)
    group.mentoring_model.allow_forum = true
    group.save
    group.create_group_forum
    mentor = group.mentors.first
    student = group.students.first
    topic1 = create_topic(forum: group.forum, user: mentor)
    post1 = create_post(topic: topic1, user: mentor)
    Group.any_instance.stubs(:forum_enabled?).returns(true)

    #viewed objects will not br created for the user who created the post
    assert_no_difference "ViewedObject.count" do
      topic1.mark_posts_viewability_for_user(mentor.id)
    end

    assert_difference "ViewedObject.count", 1 do
      topic1.mark_posts_viewability_for_user(student.id)
    end
  end
end