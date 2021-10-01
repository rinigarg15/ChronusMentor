require_relative './../../../../test_helper'

class GroupStateChangeElasticsearchQueriesTest < ActiveSupport::TestCase
  def test_get_group_state_changes_per_day
    program = programs(:albers)
    end_time =  program.created_at + 99.days
    total_additions = GroupStateChange.where("group_id in (?) AND (from_state NOT IN (?) OR from_state is NULL) AND to_state IN (?) AND created_at <= ?", program.groups.pluck(:id), ["#{Group::Status::ACTIVE}", "#{Group::Status::INACTIVE}"], ["#{Group::Status::ACTIVE}", "#{Group::Status::INACTIVE}"], end_time).count
    total_removals = GroupStateChange.where("group_id in (?) AND (to_state NOT IN (?) OR to_state is NULL) AND from_state IN (?) AND created_at <= ?", program.groups.pluck(:id), ["#{Group::Status::ACTIVE}", "#{Group::Status::INACTIVE}"], ["#{Group::Status::ACTIVE}", "#{Group::Status::INACTIVE}"], end_time).count
    additions_per_day = GroupStateChange.get_group_state_changes_per_day(program, nil, end_time).response.aggregations.additions_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}
    removals_per_day = GroupStateChange.get_group_state_changes_per_day(program, nil, end_time).response.aggregations.removals_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}
    assert_equal 100, additions_per_day.size
    assert_equal total_additions, additions_per_day.sum
    assert_equal 100, removals_per_day.size
    assert_equal total_removals, removals_per_day.sum

    time = end_time - 5.days
    date_id = time.utc.to_i/1.day.to_i

    change_1 = groups(:drafted_group_1).state_changes.create!(:date_id => date_id, :from_state => nil, :to_state => "#{Group::Status::ACTIVE}")
    change_2 = groups(:drafted_group_1).state_changes.create!(:date_id => date_id, :to_state => "#{Group::Status::DRAFTED}", :from_state => "#{Group::Status::ACTIVE}")

    reindex_documents(created: [change_1, change_2])

    assert_equal additions_per_day[-6] + 1, GroupStateChange.get_group_state_changes_per_day(program, nil, end_time).response.aggregations.additions_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}[-6]
    assert_equal removals_per_day[-6] + 1, GroupStateChange.get_group_state_changes_per_day(program, nil, end_time).response.aggregations.removals_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}[-6]
  end


  def test_get_group_state_changes_per_day_with_group_ids
    program = programs(:albers)
    group_1 = groups(:drafted_group_1)
    group_ids_except_group_1 = program.groups.pluck(:id) - [group_1.id]
    end_time =  program.created_at + 99.days
    additions_per_day = GroupStateChange.get_group_state_changes_per_day(program, nil, end_time).response.aggregations.additions_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}
    removals_per_day = GroupStateChange.get_group_state_changes_per_day(program, nil, end_time).response.aggregations.removals_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}

    time = end_time - 5.days
    date_id = time.utc.to_i/1.day.to_i

    change_1 = group_1.state_changes.create!(:date_id => date_id, :from_state => nil, :to_state => "#{Group::Status::ACTIVE}")
    change_2 = group_1.state_changes.create!(:date_id => date_id, :to_state => "#{Group::Status::DRAFTED}", :from_state => "#{Group::Status::ACTIVE}")

    reindex_documents(created: [change_1, change_2])

    state_changes_with_group_1 = GroupStateChange.get_group_state_changes_per_day(program, nil, end_time).response.aggregations
    state_changes_without_group_1 = GroupStateChange.get_group_state_changes_per_day(program, group_ids_except_group_1, end_time).response.aggregations
    assert_equal additions_per_day[-6] + 1, state_changes_with_group_1.additions_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}[-6]
    assert_equal removals_per_day[-6] + 1, state_changes_with_group_1.removals_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}[-6]
    assert_equal additions_per_day[-6], state_changes_without_group_1.additions_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}[-6]
    assert_equal removals_per_day[-6], state_changes_without_group_1.removals_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}[-6]
  end

  def test_get_group_state_changes_per_day
    program  = programs(:albers)
    state = Group::Status::ACTIVE_CRITERIA
    start_date_id = program.created_at.utc.to_i/1.day.to_i
    GroupStateChange.any_instance.stubs(:common_esearch_aggregation_query_executor)

    end_time = program.created_at + 5.days
    end_date_id = end_time.utc.to_i/1.day.to_i
    GroupStateChange.expects(:get_get_group_state_changes_per_day_aggregation).with("to_state", start_date_id, end_date_id, state, program)
    GroupStateChange.expects(:get_get_group_state_changes_per_day_aggregation).with("from_state", start_date_id, end_date_id, state, program)
    GroupStateChange.get_group_state_changes_per_day(program, nil, end_time, state)

    end_time = program.created_at - 5.days
    end_date_id = end_time.utc.to_i/1.day.to_i
    GroupStateChange.expects(:get_get_group_state_changes_per_day_aggregation).with("to_state", start_date_id, start_date_id, state, program)
    GroupStateChange.expects(:get_get_group_state_changes_per_day_aggregation).with("from_state", start_date_id, start_date_id, state, program)
    GroupStateChange.get_group_state_changes_per_day(program, nil, end_time, state)
  end
end