require_relative './../../../../../../test_helper'

class PostPopulatorTest < ActiveSupport::TestCase
  def test_add_posts
    program = programs(:albers)
    count = 1
    topic_populator = TopicPopulator.new("topic", {parent: "forum", percents_ary: [50, 25, 25], counts_ary: [3, 2, 1]})
    forum_ids = program.forums.pluck(:id).first(5)
    assert_difference "Topic.count", forum_ids.size * count do
      topic_populator.add_topics(forum_ids, count, {program: program})
    end
    to_add_topic_ids = program.topics.pluck(:id).first(5)
    to_remove_topic_ids = Post.pluck(:topic_id).uniq.last(5)
    populator_add_and_remove_objects("post", "topic", to_add_topic_ids, to_remove_topic_ids, {program: program})
  end

  def test_add_posts_for_portal
    program = programs(:primary_portal)
    count = 1
    topic_populator = TopicPopulator.new("topic", {parent: "forum", percents_ary: [50, 25, 25], counts_ary: [3, 2, 1]})
    forum_ids = [create_forum(program: program, name: "Test Forum", access_role_names: [:employee]).id]
    assert_difference "Topic.count", forum_ids.size * count do
      topic_populator.add_topics(forum_ids, count, {program: program})
    end
    to_add_topic_ids = program.reload.topics.pluck(:id).first(5)
    to_remove_topic_ids = [] || Post.pluck(:topic_id).uniq.last(5)
    populator_add_and_remove_objects("post", "topic", to_add_topic_ids, to_remove_topic_ids, {program: program})
  end
end