require_relative './../../../test_helper.rb'

class ForumExtensions::CommonInclusionsTest < ActiveSupport::TestCase
  include ForumExtensions::CommonInclusions

  def setup
    super
    @current_program = programs(:albers)
  end

  def test_authorize_user
    @forum = forums(:common_forum)
    user = users(:f_admin)

    self.expects(:current_user).once.returns(user)
    @forum.expects(:can_be_accessed_by?).with(user, :read_only).returns("Allow!")
    assert_equal "Allow!", authorize_user
  end

  def test_check_group_forum
    @forum = forums(:common_forum)
    assert_false check_group_forum

    group_forum_setup
    assert check_group_forum
  end

  def test_associated_group_pending
    group_forum_setup
    self.stubs(:check_group_forum).returns(false)
    assert_false associated_group_pending?

    self.stubs(:check_group_forum).returns(true)
    Group.any_instance.expects(:pending?).returns(false)
    assert_false associated_group_pending?

    Group.any_instance.expects(:pending?).returns(true)
    assert associated_group_pending?
  end

  def test_associated_group_active
    group_forum_setup
    self.stubs(:check_group_forum).returns(false)
    assert_false associated_group_active?

    self.stubs(:check_group_forum).returns(true)
    Group.any_instance.expects(:active?).returns(false)
    assert_false associated_group_active?

    Group.any_instance.expects(:active?).returns(true)
    assert associated_group_active?
  end

  def test_check_program_forum
    @forum = forums(:common_forum)
    assert check_program_forum

    group_forum_setup
    assert_false check_program_forum
  end

  def test_check_forum_feature
    @current_program.expects(:forums_enabled?).once.returns("Enabled!")
    assert_equal "Enabled!", check_forum_feature
  end

  def test_add_group_id_to_params
    group_forum_setup
    params = { forum_id: @forum.id }
    setup_params(params)

    add_group_id_to_params
    assert_equal_hash( {
      forum_id: @forum.id,
      group_id: @group.id
    }, params)
  end

  def test_fetch_posts_admin_user
    setup_params
    @topic = create_topic
    @forum = @topic.forum
    posts = 5.times.collect { create_post(topic: @topic, published: false) }
    posts += 6.times.collect { create_post(topic: @topic) }

    self.expects(:current_user).returns(users(:f_admin))
    fetch_posts
    assert_equal posts[0..10].reverse, @posts.to_a
    assert_equal_hash( {
      sort_field: "id",
      sort_order: "desc"
    }, @sort_fields)
  end

  def test_fetch_posts_non_admin_user
    setup_params(sort_order: "asc", sort_field: "id")
    @topic = create_topic
    @forum = @topic.forum
    5.times.collect { create_post(topic: @topic, published: false) }
    posts = 6.times.collect { create_post(topic: @topic) }

    self.expects(:current_user).returns(users(:f_mentor))
    fetch_posts
    assert_equal posts, @posts
    assert_equal_hash( {
      sort_field: "id",
      sort_order: "asc"
    }, @sort_fields)
  end

  def test_fetch_posts_pagination_and_sorting
    setup_params(sort_order: "asc", sort_field: "id", page: 2)
    @topic = create_topic
    @forum = @topic.forum
    posts = 10.times.collect { create_post(topic: @topic) }
    posts += 10.times.collect { create_post(topic: @topic) }

    self.expects(:current_user).returns(users(:f_admin))
    fetch_posts
    assert_equal posts[0..19], @posts.to_a
    assert_equal_hash( {
      sort_field: "id",
      sort_order: "asc"
    }, @sort_fields)
  end

  def test_fetch_recent_topics
    @forum = forums(:common_forum)
    @topic = create_topic(sticky_position: 1)
    sticky_topics = 3.times.collect { create_topic(sticky_position: 1) }
    topics = 5.times.collect { create_topic }

    fetch_recent_topics
    assert_equal (sticky_topics.reverse + topics[3..4].reverse), @recent_topics
  end

  private

  def setup_params(params_hash = {})
    self.stubs(:params).returns(params_hash)
  end
end