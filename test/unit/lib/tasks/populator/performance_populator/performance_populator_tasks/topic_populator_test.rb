require_relative './../../../../../../test_helper'

class TopicPopulatorTest < ActiveSupport::TestCase
  def test_add_topics
    program = programs(:albers)
    to_add_forum_ids = program.forums.pluck(:id).first(5)
    to_remove_forum_ids = Topic.pluck(:forum_id).uniq.last(5)
    populator_add_and_remove_objects("topic", "forum", to_add_forum_ids, to_remove_forum_ids, {program: program})
  end

  def test_add_topics_for_portal
    program = programs(:primary_portal)
    create_forum(program: program, access_role_names: [:employee])
    to_add_forum_ids = program.reload.forums.pluck(:id).first(5)
    to_remove_forum_ids = Topic.pluck(:forum_id).uniq.last(5)
    populator_add_and_remove_objects("topic", "forum", to_add_forum_ids, to_remove_forum_ids, {program: program})
  end
end