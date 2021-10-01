require_relative './../../test_helper.rb'

class PostObserverTest < ActiveSupport::TestCase

  def test_unpublished
    mentor_1 = users(:mentor_8)
    mentor_2 = users(:mentor_9)
    student_1 = users(:student_9)
    forum = create_forum(access_role_names: [RoleConstants::STUDENT_NAME, RoleConstants::MENTOR_NAME])
    topic = create_topic(forum: forum, user: mentor_2)
    post = nil
    topic.subscribe_user(mentor_2)
    topic.subscribe_user(student_1)

    fetch_role(:albers, RoleConstants::STUDENT_NAME).remove_permission("view_mentors")
    assert_no_difference "JobLog.count" do
      assert_no_difference "RecentActivity.count" do
        assert_difference "Subscription.count", 2 do
          assert_no_emails do
            post = create_post(topic: topic, user: mentor_1, published: false)
          end
        end
      end
    end
    assert forum.subscribed_by?(mentor_1)
    assert topic.subscribed_by?(mentor_1)

    Push::Base.expects(:queued_notify).once
    assert_difference "JobLog.count" do
      assert_difference "RecentActivity.count" do
        assert_no_difference "Subscription.count" do
          assert_emails do
            post.published = true
            post.save!
          end
        end
      end
    end
    ra_and_email_assertions(post, mentor_2)
  end

  def test_published_in_program_forum
    mentor_1 = users(:mentor_8)
    mentor_2 = users(:mentor_9)
    student_1 = users(:student_9)
    forum = create_forum(access_role_names: [RoleConstants::STUDENT_NAME, RoleConstants::MENTOR_NAME])
    topic = create_topic(forum: forum, user: mentor_2)
    post = nil
    topic.subscribe_user(mentor_2)
    topic.subscribe_user(student_1)

    fetch_role(:albers, RoleConstants::STUDENT_NAME).remove_permission("view_mentors")
    Push::Base.expects(:queued_notify).once
    assert_difference "JobLog.count", 1 do
      assert_difference "RecentActivity.count",1 do
        assert_difference "Subscription.count", 2 do
          assert_emails do
            post = create_post(topic: topic, user: mentor_1)
          end
        end
      end
    end
    assert forum.subscribed_by?(mentor_1)
    assert topic.subscribed_by?(mentor_1)
    ra_and_email_assertions(post, mentor_2)

    Push::Base.expects(:queued_notify).never
    assert_no_difference "JobLog.count" do
      assert_no_emails do
        PostObserver.send(:send_emails, post.id)
      end
    end

    assert_difference "JobLog.count", -1 do
      post.destroy
    end
  end

  def test_published_in_group_forum
    Group.any_instance.stubs(:forum_enabled?).returns(true)
    group = groups(:mygroup)
    group_mentor = group.mentors.first
    group_student = group.students.first
    group.create_group_forum
    forum = group.forum
    topic = create_topic(forum: forum, user: group_mentor)
    topic.toggle_subscription(group_student)
    assert_false topic.subscribed_by?(group_student)
    post = nil

    fetch_role(:albers, RoleConstants::MENTOR_NAME).remove_permission("view_students")
    Push::Base.expects(:queued_notify).once
    assert_no_difference "RecentActivity.count" do
      assert_difference "Subscription.count" do
        assert_difference "JobLog.count" do
          assert_no_emails do
            post = create_post(user: group_student, topic: topic)
          end
        end
      end
    end
    assert topic.reload.subscribed_by?(group_student)

    Push::Base.expects(:queued_notify).never
    assert_no_difference "JobLog.count" do
      PostObserver.send(:send_emails, post.id)
    end
  end

  def test_after_save
    group = groups(:group_pbe_4)
    forum = group.forum
    user = group.members.first
    topic = create_topic(forum: forum, user: user)

    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Group, [group.id])
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Topic, [topic.id])
    create_post(topic: topic, user: user)
  end

  def test_after_destroy
    group = groups(:group_pbe_4)
    forum = group.forum
    user = group.members.first
    topic = create_topic(forum: forum, user: user)
    post = create_post(topic: topic, user: user)

    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Group, [group.id])
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Topic, [topic.id])
    post.destroy
  end

  private

  def ra_and_email_assertions(post, user_notified)
    email = ActionMailer::Base.deliveries.last
    assert_equal [user_notified.email], email.to
    recent_activity = RecentActivity.last
    assert_equal RecentActivityConstants::Type::POST_CREATION, recent_activity.action_type
    assert_equal post, recent_activity.ref_obj
    assert_equal post.user.member, recent_activity.member
    assert_equal [post.program], recent_activity.programs
    assert_equal RecentActivityConstants::Target::ALL, recent_activity.target
  end
end