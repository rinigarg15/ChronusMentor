require_relative './../../../../test_helper'

class MentorRequestElasticsearchQueriesTest < ActiveSupport::TestCase

  def test_get_filtered_mentor_requests
    search_params = {search_filters: {sender: "example", receiver: "Good unique"}}
    filter_conditions = { program_id: programs(:albers).id }
    results = MentorRequest.get_filtered_mentor_requests(search_params, filter_conditions, true)
    assert_equal_unordered [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], results.collect(&:id)

    # with source_columns
    results = MentorRequest.get_filtered_mentor_requests(search_params, filter_conditions, true, ["sender_id", "receiver_id"])

    e = assert_raises(NoMethodError) do
      results.collect(&:status)
    end
    assert_match /undefined method `status' for /, e.message
    assert_equal [3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3], results.collect(&:receiver_id)
    assert_equal_unordered [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20], results.collect(&:sender_id)

    # with sorted on id
    search_params.merge!(sort_field: "id", sort_order: "desc")
    results = MentorRequest.get_filtered_mentor_requests(search_params, filter_conditions, true)
    assert_equal [12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2], results.collect(&:id)

    # Test pagination
    search_params.merge!(page: 1, per_page: 2)
    results = MentorRequest.get_filtered_mentor_requests(search_params, filter_conditions)
    assert_equal 11, results.total_entries
    assert_equal 6, results.total_pages
    assert_equal [12, 11], results.collect(&:id)
    search_params.merge!(page: 2)
    results = MentorRequest.get_filtered_mentor_requests(search_params, filter_conditions)
    assert_equal [10, 9], results.collect(&:id)
    search_params.merge!(page: 6)
    results = MentorRequest.get_filtered_mentor_requests(search_params, filter_conditions)
    assert_equal [2], results.collect(&:id)

    search_params = {sort_field: "id", sort_order: "desc"}
    filter_conditions = { program_id: programs(:moderated_program).id }
    source_columns = ["id"]
    results = MentorRequest.get_filtered_mentor_requests(search_params, filter_conditions, true, source_columns)
    assert_equal ["1"], results.collect(&:id)

    search_params.merge!(search_filters: {expiry_date: "#{30.days.ago.strftime("%m/%d/%Y")} - #{30.days.from_now.strftime("%m/%d/%Y")}"})
    filter_conditions = { program_id: programs(:albers).id }
    results = MentorRequest.get_filtered_mentor_requests(search_params, filter_conditions)
    assert_equal [21, 20, 18, 17, 12, 11, 10, 9, 8, 7], results.collect(&:id)
  end

  def test_get_mentor_requests_search_count
    search_params = {search_filters: {sender: "example", receiver: "Good unique"}}
    filter_conditions = { program_id: programs(:albers).id }
    count = MentorRequest.get_mentor_requests_search_count(search_params, filter_conditions)
    assert_equal 11, count

    search_params = {search_filters: {sender: nil, receiver: nil}}
    filter_conditions = { program_id: programs(:albers).id }
    count = MentorRequest.get_mentor_requests_search_count(search_params, filter_conditions)
    assert_equal 15, count
  end
end