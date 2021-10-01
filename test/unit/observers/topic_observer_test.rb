require_relative './../../test_helper.rb'

class TopicObserverTest < ActiveSupport::TestCase

  def test_afer_create_program_forum
    forum = forums(:common_forum)
    topic = nil
    user = users(:student_8)
    assert_false forum.subscribed_by?(user)

    dj_mock = mock()
    Topic.expects(:delay).returns(dj_mock).once
    dj_mock.expects(:notify_subscribers).once
    assert_difference "RecentActivity.count", 1 do
      assert_difference "Subscription.count", 2 do
        topic = create_topic(user: user)
      end
    end
    assert forum.subscribed_by?(user)
    assert topic.subscribed_by?(user)

    recent_activity = RecentActivity.last
    assert_equal RecentActivityConstants::Type::TOPIC_CREATION, recent_activity.action_type
    assert_equal user.member, recent_activity.member
    assert_equal forum.recent_activity_target, recent_activity.target
    assert_equal topic, recent_activity.ref_obj
    assert_equal [forum.program], recent_activity.programs
  end

  def test_after_create_group_forum
    Group.any_instance.stubs(:forum_enabled?).returns(true)
    group = groups(:mygroup)
    group.create_group_forum
    forum = group.forum
    topic = nil
    group_mentor = group.mentors.first
    group_student = group.students.first

    dj_mock = mock()
    Topic.expects(:delay).returns(dj_mock).once
    dj_mock.expects(:notify_subscribers).once
    assert_no_difference "RecentActivity.count" do
      assert_difference "Subscription.count", 2 do
        topic = create_topic(forum: forum, user: group_mentor)
      end
    end
    assert topic.subscribed_by?(group_mentor)
    assert topic.subscribed_by?(group_student)
  end
end