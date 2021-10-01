require_relative './../../../../test_helper'

class AbstractMessageElasticsearchQueriesTest < ActiveSupport::TestCase
  def setup
    super
    message = messages(:first_message)
    message.update_attributes!(content: "<a href=\"<a href=\"http://test-p1.chronus.com\">http://test-p1.chronus.com</a>\"Click Here /a>")
    reindex_documents(updated: message)
  end

  def test_get_filtered_messages_from_es
    # first_admin_message doesn't have "hello" in neither of subject or content.
    message_ids = messages(:mygroup_mentor_1, :mygroup_student_1, :first_admin_message).map(&:id)
    results = AbstractMessage.get_filtered_messages_from_es("Subject", message_ids)
    assert_equal_unordered message_ids - [messages(:first_admin_message).id], collect_ids(results)

    # empty search
    results = AbstractMessage.get_filtered_messages_from_es("", message_ids)
    assert_equal_unordered message_ids, collect_ids(results)

    message_ids = messages(:first_message, :mygroup_student_1, :mygroup_student_2, :meeting_scrap).map(&:id)
    results = AbstractMessage.get_filtered_messages_from_es("", message_ids)
    assert_equal message_ids.reverse, collect_ids(results)

    #search html tags
    results = AbstractMessage.get_filtered_messages_from_es("href", [messages(:first_message).id])
    assert_empty collect_ids(results)

    results = AbstractMessage.get_filtered_messages_from_es("Click Here", [messages(:first_message).id])
    assert_equal [messages(:first_message).id], collect_ids(results)

    results = AbstractMessage.get_filtered_messages_from_es("http://test-p1.chronus.com", [messages(:first_message).id])
    assert_equal [messages(:first_message).id], collect_ids(results)

    results = AbstractMessage.get_filtered_messages_from_es("http", [messages(:first_message).id])
    assert_equal [messages(:first_message).id], collect_ids(results)

    results = AbstractMessage.get_filtered_messages_from_es("chronus", [messages(:first_message).id])
    assert_equal [messages(:first_message).id], collect_ids(results)

    results = AbstractMessage.get_filtered_messages_from_es("chronus.com", [messages(:first_message).id])
    assert_equal [messages(:first_message).id], collect_ids(results)

    results = AbstractMessage.get_filtered_messages_from_es("test-p1", [messages(:first_message).id])
    assert_equal [messages(:first_message).id], collect_ids(results)
  end

  private

  def collect_ids(results)
    results.aggregations.group_by_root_id.buckets.collect {|bucket| bucket[:key]}
  end
end
