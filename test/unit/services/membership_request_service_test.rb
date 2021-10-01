require_relative './../../test_helper.rb'

class MembershipRequestServiceTest < ActiveSupport::TestCase

  def test_filters_to_apply
    output1 = MembershipRequestService.filters_to_apply({}, MembershipRequest::ListStyle::DETAILED, programs(:albers))
    assert_equal_hash processed_filters, output1

    output2 = MembershipRequestService.filters_to_apply( { sort: "question", order: "none", filters: { role: RoleConstants::MENTOR_NAME } }, MembershipRequest::ListStyle::LIST, programs(:albers))
    processed_filters_hash = processed_filters(sort_field: "question", sort_order: "none", sort_scope: [:order_by, "question", "none"], filters: {role: RoleConstants::MENTOR_NAME})
    assert_equal_hash processed_filters_hash, output2

    filters = {role: RoleConstants::MENTOR_NAME, report: "something", date_range: "Something else"}
    MembershipRequestService.stubs(:get_default_sort_field).with('fruit').returns('mango')
    MembershipRequestService.stubs(:get_default_sort_order).with('fruit').returns('apple')
    ReportsFilterService.stubs(:get_report_date_range).with(filters, programs(:albers).created_at).returns([1,2])
    output3 = MembershipRequestService.filters_to_apply({filters: filters}, 'fruit', programs(:albers))
    processed_filters_hash = processed_filters(sort_field: "mango", sort_order: "apple", sort_scope: [:order_by, "mango", "apple"], filters: {role: RoleConstants::MENTOR_NAME, report: "something", date_range: "Something else", start_date: 1, end_date: 2})
    assert_equal_hash processed_filters_hash, output3

    MembershipRequestService.stubs(:get_default_sort_field).with('fruit').returns('mango')
    MembershipRequestService.stubs(:get_default_sort_order).with('fruit').returns('apple')
    ReportsFilterService.stubs(:get_report_date_range).with(filters.merge({:date_range => 'nothing'}), programs(:albers).created_at).returns([3,4])
    output4 = MembershipRequestService.filters_to_apply({sent_between: "nothing", filters: filters}, 'fruit', programs(:albers))
    processed_filters_hash = processed_filters(sort_field: "mango", sort_order: "apple", sort_scope: [:order_by, "mango", "apple"], filters: {role: RoleConstants::MENTOR_NAME, report: "something", date_range: "nothing", start_date: 3, end_date: 4})
    assert_equal_hash processed_filters_hash, output4
  end

  def test_get_filtered_membership_requests
    program = programs(:albers)
    pending_membership_requests = program.membership_requests.not_joined_directly.pending
    accepted_membership_requests = program.membership_requests.not_joined_directly.accepted
    assert_equal 12, pending_membership_requests.size
    assert_equal 0, accepted_membership_requests.size

    MembershipRequestService.stubs(:filters_to_apply).with("filters_hash", "list_type", program).returns("some filters").times(3)
    MembershipRequestService.stubs(:apply_filters).with("some filters").returns([program.membership_requests.pending.pluck(:id), "prev_period_ids"]).times(3)
    MembershipRequestService.stubs(:get_tiles_data).with("prev_period_ids", program.membership_requests.pending.pluck(:id)).returns("tiles_data").once

    output = MembershipRequestService.get_filtered_membership_requests(program, "filters_hash", "list_type", MembershipRequest::FilterStatus::PENDING)
    assert_equal 4, output.size
    assert_equal "some filters", output[0]
    assert_equal "tiles_data", output[1]
    assert_equal 0, output[2]
    assert_equal pending_membership_requests, output[3]

    assert_equal pending_membership_requests, MembershipRequestService.get_filtered_membership_requests(program, "filters_hash", "list_type", MembershipRequest::FilterStatus::PENDING, true)
    assert_equal accepted_membership_requests, MembershipRequestService.get_filtered_membership_requests(program, "filters_hash", "list_type", MembershipRequest::FilterStatus::ACCEPTED, true)
  end

  def test_get_default_sort_field
    assert_equal "first_name", MembershipRequestService.send(:get_default_sort_field, MembershipRequest::ListStyle::LIST)
    assert_equal "id", MembershipRequestService.send(:get_default_sort_field, "any thing else")
  end

  def test_get_default_sort_order
    assert_equal "asc", MembershipRequestService.send(:get_default_sort_order, MembershipRequest::ListStyle::LIST)
    assert_equal "desc", MembershipRequestService.send(:get_default_sort_order, "any thing else")
  end

  def test_apply_filters
    program = programs(:albers)
    MembershipRequestService.instance_variable_set("@program", program)
    MembershipRequestService.instance_variable_set("@other_filters_count", 10)

    processed_filters = {filters: {role: MembershipRequestService::Filter::Role::ALL}}
    membership_requests = program.membership_requests.includes(:member).not_joined_directly
    member_ids = membership_requests.pluck :member_id
    MembershipRequestService.stubs(:get_member_ids_based_on_profile).with(member_ids, processed_filters).returns([7777, 8888])
    MembershipRequestService.stubs(:apply_time_filter).with(membership_requests.where(member_id: [7777, 8888]), processed_filters).returns("result")

    assert_equal "result", MembershipRequestService.send(:apply_filters, processed_filters)
    assert_equal 10, MembershipRequestService.instance_variable_get("@other_filters_count")
  end

  def test_apply_filters_role_filter
    program = programs(:albers)
    MembershipRequestService.instance_variable_set("@program", program)
    MembershipRequestService.instance_variable_set("@other_filters_count", 10)

    processed_filters = {filters: {role: RoleConstants::MENTOR_NAME}}
    membership_requests = program.membership_requests.includes(:member).not_joined_directly.for_role(RoleConstants::MENTOR_NAME)
    MembershipRequestService.stubs(:get_member_ids_based_on_profile).with(membership_requests.pluck(:member_id), processed_filters).returns([7777, 8888])
    MembershipRequestService.stubs(:apply_time_filter).with(membership_requests.where(member_id: [7777, 8888]), processed_filters).returns("result")

    assert_equal "result", MembershipRequestService.send(:apply_filters, processed_filters)
    assert_equal 11, MembershipRequestService.instance_variable_get("@other_filters_count")
  end

  def test_get_member_ids_based_on_profile
    MembershipRequestService.instance_variable_set("@other_filters_count", 10)
    processed_filters = {filters: {}}
    assert_equal 'member_ids', MembershipRequestService.send(:get_member_ids_based_on_profile, 'member_ids', processed_filters)
    assert_equal 10, MembershipRequestService.instance_variable_get("@other_filters_count")

    processed_filters = {filters: {report: {profile_questions: 'some_hash'}}}
    Survey::Report.stubs(:remove_incomplete_report_filters).with('some_hash').returns('some_filters')
    ReportsFilterService.stubs(:dynamic_profile_filter_params).with('some_filters').returns('dynamic filters')
    UserAndMemberFilterService.stubs(:apply_profile_filtering).with('member_ids', 'dynamic filters', {:for_report_filter => true}).returns('result')
    assert_equal 'result', MembershipRequestService.send(:get_member_ids_based_on_profile, 'member_ids', processed_filters)
    assert_equal 11, MembershipRequestService.instance_variable_get("@other_filters_count")
  end

  def test_apply_time_filter
    start_date = "15, january 2016".to_date
    end_date =  "25, january 2016".to_date
    MembershipRequestService.instance_variable_set("@program", programs(:albers))
    processed_filters = {filters: {start_date: start_date, end_date: end_date}}
    Program.any_instance.stubs(:created_at).returns("10, january 2016".to_time)

    MembershipRequestService.stubs(:get_membership_request_ids_between).with('membership_requests', start_date, end_date).returns('current_ids').twice
    assert_equal ['current_ids', nil], MembershipRequestService.send(:apply_time_filter, 'membership_requests', processed_filters)

    MembershipRequestService.stubs(:get_membership_request_ids_between).with('membership_requests', "4, january 2016".to_date, "14, january 2016".to_date).returns('prev_ids').once
    Program.any_instance.stubs(:created_at).returns("1, january 2016".to_time)
    assert_equal ['current_ids', 'prev_ids'], MembershipRequestService.send(:apply_time_filter, 'membership_requests', processed_filters)
  end

  def test_get_membership_request_ids_between
    Time.zone = "UTC"
    start_date = "01, July, 2100".to_date
    end_date = "01, July, 2100".to_date
    mr = programs(:albers).membership_requests.last
    mr.update_attribute(:created_at, '2100-07-01 00:00:01 +0000'.to_time)
    membership_requests = programs(:albers).membership_requests

    assert_equal [mr.id], MembershipRequestService.send(:get_membership_request_ids_between, membership_requests, start_date, end_date)

    Time.zone = "US/Pacific-New"
    assert_equal [], MembershipRequestService.send(:get_membership_request_ids_between, membership_requests, start_date, end_date)
  end

  def test_get_tiles_data
    current_period_ids = [3]
    prev_period_ids = [1,2]
    ReportsFilterService.stubs(:get_percentage_change).with(2, 1).returns('%')
    MembershipRequestService.stubs(:get_scoped_membership_request_counts).with(current_period_ids).returns({fruit: 'apple'})
    assert_equal_hash({fruit: 'apple', percentage: '%', prev_periods_count: 2}, MembershipRequestService.send(:get_tiles_data, prev_period_ids, current_period_ids))
  end

  def test_get_scoped_membership_request_counts
    membership_requests = programs(:albers).membership_requests
    mf = membership_requests.first
    mf.update_column(:status, MembershipRequest::Status::ACCEPTED)
    ml = membership_requests.last
    ml.update_column(:status, MembershipRequest::Status::REJECTED)
    all = membership_requests.pluck(:id).size

    MembershipRequestService.stubs(:get_membership_requests).with("membership_request_ids").returns(membership_requests).times(4)
    assert_equal_hash({pending: (all-2), accepted: 1, rejected: 1, received: all}, MembershipRequestService.send(:get_scoped_membership_request_counts, 'membership_request_ids'))
  end

  def test_get_filtered_membership_requests_location_filter
    program = programs(:albers)
    MembershipRequestService.instance_variable_set("@program", program)
    mf = program.membership_requests.first
    mf.update_attribute(:joined_directly, true)

    assert_equal [], MembershipRequestService.send(:get_membership_requests, [])
    assert_equal (program.membership_requests.pluck(:id) - [mf.id]), MembershipRequestService.send(:get_membership_requests, program.membership_requests.pluck(:id)).pluck(:id)
  end

  private

  def processed_filters(filters = {})
    filter_hash = {
      sort_field: "id",
      sort_order: "desc",
      sort_scope: [:order_by, "id", "desc"],
      filters: {start_date: programs(:albers).created_at.to_date, end_date: Time.current.to_date, role: MembershipRequestService::Filter::Role::ALL}
    }
    filter = filters.delete(:filters)
    filter_hash[:filters].merge!(filter) if filter.present?
    filter_hash.merge!(filters)
  end
end