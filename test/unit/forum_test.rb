require_relative './../test_helper.rb'

class ForumTest < ActiveSupport::TestCase

  def test_validations
    e = assert_raise(ActiveRecord::RecordInvalid) do
      Forum.create!
    end
    assert_match(/Name can't be blank/, e.message)
    assert_match(/Available For can't be blank/, e.message)
    assert_match(/Program can't be blank/, e.message)
  end

  def test_uniqueness_of_names
    assert_raise ActiveRecord::RecordInvalid, :name do
      create_forum(name: forums(:forums_2).name)
    end
  end

  def test_create_program_forum
    assert_difference "RecentActivity.count" do
      assert_difference "Forum.count" do
        create_forum(name: "Program Forum")
      end
    end
    forum = Forum.last
    assert_equal "Program Forum", forum.name
    assert_equal programs(:albers), forum.program
    assert_equal [RoleConstants::MENTOR_NAME], forum.access_role_names

    recent_activity = RecentActivity.last
    assert_equal forum, recent_activity.ref_obj
    assert_equal RecentActivityConstants::Type::FORUM_CREATION, recent_activity.action_type
    assert_equal RecentActivityConstants::Target::MENTORS, recent_activity.target
  end

  def test_create_group_forum
    group = groups(:mygroup)
    assert_no_difference "RecentActivity.count" do
      assert_difference "Forum.count" do
        create_forum(name: "Group Forum", description: "Discussion Board", group_id: group.id)
      end
    end
    forum = Forum.last
    assert_equal "Group Forum", forum.name
    assert_equal "Discussion Board", forum.description
    assert_equal programs(:albers), forum.program
    assert_equal group, forum.group
    assert_empty forum.access_role_names
  end

  def test_no_recent_activity_for_non_default_admin_roles
    program = programs(:albers)
    program.create_role(RoleConstants::BOARD_OF_ADVISOR_NAME)

    assert_no_difference "RecentActivity.count" do
      assert_difference "Forum.count" do
        forum = program.forums.new(name: "Test")
        forum.access_role_names = [RoleConstants::BOARD_OF_ADVISOR_NAME]
        forum.save!
      end
    end
  end

  def test_recent_activity_target
    forum = forums(:forums_1)
    assert_equal [RoleConstants::STUDENT_NAME], forum.access_role_names
    assert_equal RecentActivityConstants::Target::MENTEES, forum.recent_activity_target

    forum.access_role_names += ["user"]
    forum.save
    assert_equal RecentActivityConstants::Target::ALL, forum.recent_activity_target

    forum.access_role_names += [RoleConstants::MENTOR_NAME]
    forum.save
    assert_equal RecentActivityConstants::Target::ALL, forum.recent_activity_target

    forum.role_references.destroy_all
    assert_nil forum.reload.recent_activity_target
  end

  def test_counter_cache_for_topics
    forum = forums(:forums_2)
    assert_equal 0, forum.topics_count

    topic_1 = create_topic(forum: forum)
    assert_equal 1, forum.reload.topics_count
    topic_2 = create_topic(forum: forum)
    assert_equal 2, forum.reload.topics_count

    topic_1.destroy
    assert_equal 1, forum.reload.topics_count
    topic_2.destroy
    assert_equal 0, forum.reload.topics_count
  end

  def test_posts_count_and_recent_post
    forum = forums(:forums_1)
    assert_equal 0, forum.posts_count
    assert_nil forum.recent_post

    topic_1 = create_topic(forum: forum)
    post_1 = create_post(topic: topic_1)
    assert_equal 1, forum.posts_count
    assert_equal post_1, forum.recent_post

    post_2 = create_post(topic: topic_1)
    assert_equal 2, forum.posts_count
    assert_equal post_2, forum.recent_post

    post_2.destroy
    assert_equal 1, forum.posts_count
    assert_equal post_1, forum.recent_post
  end

  def test_available_for_student
    assert_false forums(:forums_2).available_for_student?
    assert forums(:forums_1).available_for_student?
    assert forums(:common_forum).available_for_student?
  end

  def test_subscription
    forum = forums(:common_forum)
    user = users(:f_mentor)
    assert forum.subscribed_by?(user)

    assert_difference "Subscription.count", -1 do
      forum.unsubscribe_user(user)
    end
    assert_false forum.subscribed_by?(user)

    assert_difference "Subscription.count" do
      forum.subscribe_user(user)
    end
    assert forum.subscribed_by?(user)
  end

  def test_total_views
    forum = forums(:forums_2)
    assert_equal 0, forum.total_views

    create_topic(forum: forum, hits: 2)
    assert_equal 2, forum.total_views

    create_topic(forum: forum, hits: 3)
    assert_equal 5, forum.total_views
  end

  def test_type
    forum = forums(:common_forum)
    assert forum.is_program_forum?
    assert_false forum.is_group_forum?
    assert Forum.program_forums.include?(forum)

    forum.group = groups(:mygroup)
    forum.save!
    assert_false forum.is_program_forum?
    assert forum.is_group_forum?
    assert_false Forum.program_forums.include?(forum)
  end

  def test_allow_moderation
    forum = forums(:common_forum)
    program = forum.program
    assert forum.is_program_forum?
    assert_false program.moderation_enabled?
    assert_false forum.allow_moderation?

    program.enable_feature(FeatureName::MODERATE_FORUMS)
    assert forum.allow_moderation?

    forum.group_id = 1
    assert_false forum.allow_moderation?
  end

  def test_allow_flagging
    forum = forums(:common_forum)
    program = forum.program
    assert forum.is_program_forum?
    assert program.flagging_enabled?
    assert forum.allow_flagging?

    forum.group_id = 1
    assert_false forum.allow_flagging?

    forum.group_id = nil
    program.enable_feature(FeatureName::FLAGGING, false)
    assert_false forum.allow_flagging?
  end

  def test_can_access_program_forum
    forum = forums(:common_forum)
    program = forum.program
    mentor = users(:f_mentor)
    student = users(:f_student)

    assert_equal_unordered [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], forum.access_role_names
    assert program.forums_enabled?
    assert forum.can_access_program_forum?(mentor)
    assert forum.can_access_program_forum?(student)

    forum.group_id = 1
    assert_false forum.can_access_program_forum?(mentor)
    assert_false forum.can_access_program_forum?(student)

    forum.group_id = nil
    forum.access_role_names = [RoleConstants::MENTOR_NAME]
    forum.save!
    assert forum.can_access_program_forum?(mentor)
    assert_false forum.can_access_program_forum?(student)

    program.enable_feature(FeatureName::FORUMS, false)
    assert_false forum.can_access_program_forum?(mentor)
    assert_false forum.can_access_program_forum?(student)
  end

  def test_can_access_group_forum
    forum = forums(:common_forum)
    group = groups(:mygroup)
    group_student = group.students.first
    group_mentor = group.mentors.first
    admin_user = users(:f_admin)
    non_group_user = users(:f_student)

    Group.any_instance.stubs(:forum_enabled?).returns(true)
    assert forum.is_program_forum?
    assert_false forum.can_access_group_forum?(group_student, true)
    assert_false forum.can_access_group_forum?(admin_user, true)

    forum.group = group
    forum.access_role_names = []
    forum.save!

    group.update_column(:status, Group::Status::DRAFTED)
    assert_false forum.can_access_group_forum?(group_student, false)

    group.update_column(:status, Group::Status::PENDING)
    assert forum.can_access_group_forum?(group_student, false)

    group.update_column(:status, Group::Status::ACTIVE)
    # Read-only
    assert forum.can_access_group_forum?(group_student, true)
    assert forum.can_access_group_forum?(group_mentor, true)
    assert forum.can_access_group_forum?(admin_user, true)
    assert_false forum.can_access_group_forum?(non_group_user, true)
    # CRUD
    assert forum.can_access_group_forum?(group_student, false)
    assert forum.can_access_group_forum?(group_mentor, false)
    assert_false forum.can_access_group_forum?(admin_user, false)
    assert_false forum.can_access_group_forum?(non_group_user, true)

    group.terminate!(admin_user, "Reason", group.program.permitted_closure_reasons.first.id)
    # Read-only
    assert forum.can_access_group_forum?(group_student, true)
    assert forum.can_access_group_forum?(group_mentor, true)
    assert forum.can_access_group_forum?(admin_user, true)
    assert_false forum.can_access_group_forum?(non_group_user, true)
    # CRUD
    assert_false forum.can_access_group_forum?(group_student, false)
    assert_false forum.can_access_group_forum?(group_mentor, false)
    assert_false forum.can_access_group_forum?(admin_user, false)
    assert_false forum.can_access_group_forum?(non_group_user, true)
  end

  def test_can_be_accessed_by
    forum = forums(:common_forum)
    user = users(:f_mentor)

    assert forum.is_program_forum?
    forum.expects(:can_access_program_forum?).with(user).returns(false).once
    forum.expects(:can_access_group_forum?).never
    assert_false forum.can_be_accessed_by?(user, :read_only)

    forum.group = groups(:mygroup)
    forum.expects(:can_access_program_forum?).never
    forum.expects(:can_access_group_forum?).with(user, true).returns(false).once
    assert_false forum.can_be_accessed_by?(user, :read_only)

    forum.expects(:can_access_program_forum?).never
    forum.expects(:can_access_group_forum?).with(user, false).returns(false).once
    assert_false forum.can_be_accessed_by?(user)
  end

  def test_create_recent_activity
    forum = forums(:common_forum)
    program = forum.program
    assert forum.is_program_forum?

    assert_difference "RecentActivity.count", 1 do
      forum.create_recent_activity
    end
    recent_activity = RecentActivity.last
    assert_equal [program], recent_activity.programs
    assert_equal RecentActivityConstants::Type::FORUM_CREATION, recent_activity.action_type
    assert_equal forum.recent_activity_target, recent_activity.target
    assert_nil recent_activity.member

    topic = create_topic
    assert_difference "RecentActivity.count", 1 do
      forum.create_recent_activity(RecentActivityConstants::Type::TOPIC_CREATION, topic)
    end
    recent_activity = RecentActivity.last
    assert_equal [program], recent_activity.programs
    assert_equal RecentActivityConstants::Type::TOPIC_CREATION, recent_activity.action_type
    assert_equal forum.recent_activity_target, recent_activity.target
    assert_equal topic.user.member, recent_activity.member

    forum.role_references.destroy_all
    assert_no_difference "RecentActivity.count" do
      forum.reload.create_recent_activity
    end
  end
end