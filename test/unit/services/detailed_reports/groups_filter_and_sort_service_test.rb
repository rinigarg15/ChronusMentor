require_relative './../../../test_helper.rb'

class DetailedReports::GroupsFilterAndSortServiceTest < ActiveSupport::TestCase
  def test_with_default_options
    program = programs(:albers)
    groups = program.groups
    group_ids = groups.collect(&:id)

    groups_1 = DetailedReports::GroupsFilterAndSortService.new(program, group_ids, {}).groups
    assert_equal 10, groups_1.size
    assert_equal [], groups_1.collect(&:id) - group_ids

    assert_equal groups.collect{|g| g.name.downcase}.sort.first(10), groups_1.collect{|g| g.name.downcase}
  end

  def test_different_with_pagination
    program = programs(:albers)
    groups = program.groups
    group_ids = groups.collect(&:id)

    groups_1 = DetailedReports::GroupsFilterAndSortService.new(program, group_ids, {page_size: 2}).groups
    assert_equal 2, groups_1.size

    groups_2 = DetailedReports::GroupsFilterAndSortService.new(program, group_ids, {page_size: 2000}).groups
    assert_equal groups.size, groups_2.size

    groups_3 = DetailedReports::GroupsFilterAndSortService.new(program, group_ids, {page_size: 2, page_number: 500}).groups
    assert_equal 0, groups_3.size
  end

  def test_with_differnet_sort_options
    program = programs(:albers)
    group_ids = [groups(:mygroup), groups(:group_2)].map(&:id)

    output = DetailedReports::GroupsFilterAndSortService.new(program, group_ids, page_size: 100).groups
    assert_equal group_ids.reverse, output.map(&:id)

    output = DetailedReports::GroupsFilterAndSortService.new(program, group_ids, page_size: 100, sort_type: 'desc').groups
    assert_equal group_ids, output.map(&:id)

    output = DetailedReports::GroupsFilterAndSortService.new(program, group_ids, page_size: 4, sort_field: DetailedReports::GroupsFilterAndSortService::Sort::Field::STARTED_ON, sort_type: 'desc').groups
    assert_equal group_ids.reverse, output.map(&:id)
  end

  def test_filter_based_on_status
    program = programs(:albers)
    groups = program.groups
    group_ids = groups.collect(&:id)
    closure_reason_ids = program.group_closure_reasons.completed.pluck(:id)

    groups_1 = DetailedReports::GroupsFilterAndSortService.new(program, group_ids, {page_size: 2000, filter: {current_status: DetailedReports::GroupsFilterAndSortService::CurrentStatus::ONGOING}}).groups
    assert_equal_unordered groups.active.collect(&:id), groups_1.collect(&:id)

    groups_2 = DetailedReports::GroupsFilterAndSortService.new(program, group_ids, {page_size: 2000, filter: {current_status: DetailedReports::GroupsFilterAndSortService::CurrentStatus::COMPLETED}}).groups
    assert_equal_unordered groups.closed.where(:closure_reason_id => closure_reason_ids).collect(&:id), groups_2.collect(&:id)

    groups_3 = DetailedReports::GroupsFilterAndSortService.new(program, group_ids, {page_size: 2000, filter: {current_status: DetailedReports::GroupsFilterAndSortService::CurrentStatus::DISCARDED}}).groups
    assert_equal_unordered groups.closed.where("closure_reason_id NOT IN (?)", closure_reason_ids).collect(&:id), groups_3.collect(&:id)
  end

  def test_filter_based_on_group_ids
    program = programs(:albers)
    groups = program.groups
    group_ids = groups.collect(&:id)

    groups_1 = DetailedReports::GroupsFilterAndSortService.new(program, [], {page_size: 2000}).groups
    assert_equal [], groups_1.to_a

    groups_2 = DetailedReports::GroupsFilterAndSortService.new(program, group_ids - [groups(:mygroup).id], {page_size: 2000}).groups
    assert_false groups_2.to_a.include?(groups(:mygroup))
  end
end