require_relative './../../../../test_helper'

class ProjectRequestElasticsearchQueriesTest < ActiveSupport::TestCase
  def test_get_filtered_project_requests
    pr = ProjectRequest.find(23)
    pr.update_attributes!(status: AbstractRequest::Status::NOT_ANSWERED)
    reindex_documents(updated: pr)
    search_params = { requestor: "student_c" }
    options = { program: programs(:pbe) }
    results = ProjectRequest.get_filtered_project_requests(search_params, options)
    assert_equal [23, 27], results.collect(&:id)
    # with source_columns
    options.merge!(source_columns: ["group_id"])
    results = ProjectRequest.get_filtered_project_requests(search_params, options)
    e = assert_raises(NoMethodError) do
      results.collect(&:sender_id)
    end
    assert_match /undefined method `sender_id' for /, e.message
    assert_equal groups(:group_pbe_1, :group_pbe_0).map(&:id), results.collect(&:group_id)

    # Test pagination
    search_params.merge!(page: 1, per_page: 1)
    options.delete(:source_columns)
    results = ProjectRequest.get_filtered_project_requests(search_params, options)
    assert_equal 2, results.total_entries
    assert_equal 2, results.total_pages
    assert_equal [23], results.collect(&:id)
    search_params.merge!(page: 2)
    results = ProjectRequest.get_filtered_project_requests(search_params, options)
    assert_equal [27], results.collect(&:id)

    options.merge!(skip_pagination: true)
    results = ProjectRequest.get_filtered_project_requests(search_params, options)
    assert_equal 2, results.total_entries
    assert_equal [23, 27], results.collect(&:id)

    search_params = {start_time: 30.days.ago.beginning_of_day.to_datetime, end_time: 2.days.from_now.end_of_day.to_datetime, page: 1}
    options = { program: programs(:pbe) }
    results = ProjectRequest.get_filtered_project_requests(search_params, options)
    assert_equal [23, 27, 28, 29, 30, 31], results.collect(&:id)

    search_params = { page: 1}
    options = { program: programs(:pbe), sender_id: users(:pbe_student_2).id }
    results = ProjectRequest.get_filtered_project_requests(search_params, options)
    assert_equal [23, 27], results.collect(&:id)

    search_params = { page: 1}
    options = { program: programs(:pbe), group_ids: [groups(:group_pbe_2).id] }
    results = ProjectRequest.get_filtered_project_requests(search_params, options)
    assert_equal [29], results.collect(&:id)

    search_params = { page: 1, project: "project_c" }
    options = { program: programs(:pbe) }
    results = ProjectRequest.get_filtered_project_requests(search_params, options)
    assert_equal [29], results.collect(&:id)

    search_params = { page: 1, status: "declined" }
    results = ProjectRequest.get_filtered_project_requests(search_params, options)
    assert_equal [22, 24, 25, 26], results.collect(&:id)
  end

  def test_get_project_requests_search_count
    pr = ProjectRequest.find(23)
    pr.update_attributes!(status: AbstractRequest::Status::NOT_ANSWERED)
    reindex_documents(updated: pr)
    search_params = {requestor: "student_c" }
    options = {program: programs(:pbe)}
    count = ProjectRequest.get_project_requests_search_count(search_params, options)
    assert_equal 2, count
  end

  def test_get_project_request_ids
    pr = ProjectRequest.find(23)
    pr.update_attributes!(status: AbstractRequest::Status::NOT_ANSWERED)
    reindex_documents(updated: pr)
    search_params = { requestor: "student_c" }
    options = { program: programs(:pbe) }
    results = ProjectRequest.get_project_request_ids(search_params, options)
    assert_equal [23, 27], results
  end
end