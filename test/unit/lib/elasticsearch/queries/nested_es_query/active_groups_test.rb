require_relative './test_helper'
require_relative './../../../../../test_helper'

class NestedEsQuery::ActiveGroupsTest < ActiveSupport::TestCase
  include NestedEsQuery::TestHelper

  def test_initialize
    program = programs(:albers)
    time_now = Time.now
    query = NestedEsQuery::ActiveGroups.new(program, program.created_at, time_now)
    assert_equal program.created_at.to_i / 1.day.to_i, query.start_date_id
    assert_equal time_now.to_i / 1.day.to_i, query.end_date_id
    assert_equal program.group_ids, query.filterable_ids

    query = NestedEsQuery::ActiveGroups.new(program, time_now - 1.day, time_now, ids: ["filterable_ids"])
    assert_equal (time_now - 1.day).to_i / 1.day.to_i, query.start_date_id
    assert_equal time_now.to_i / 1.day.to_i, query.end_date_id
    assert_equal ["filterable_ids"], query.filterable_ids
  end

  def test_get_filtered_ids
    program = programs(:albers)
    query = NestedEsQuery::ActiveGroups.new(program, program.created_at, Time.now)
    assert_filtered_ids(query, groups(:mygroup, :group_2, :group_3, :group_4, :group_5, :group_inactive, :old_group).map(&:id))

    query.end_date_id = query.start_date_id
    assert_filtered_ids(query, [])
  end

  def test_get_filtered_ids_when_group_ids
    program = programs(:albers)
    time = 3.days.ago
    query = NestedEsQuery::ActiveGroups.new(program, program.created_at, time)
    initial_count = nil
    query_executor(query) { initial_count = query.get_filtered_ids.size }

    group = groups(:drafted_group_1)
    state_change = group.state_changes.last
    date_id = time.utc.to_i / 1.day.to_i
    state_change.update_attributes(date_id: date_id, to_state: "#{Group::Status::ACTIVE}")
    reindex_documents(updated: group)
    query_executor(query) { assert_equal initial_count + 1, query.get_filtered_ids.size }

    group_ids = program.group_ids - [group.id]
    query = NestedEsQuery::ActiveGroups.new(program, program.created_at, time, ids: group_ids)
    query_executor(query) { assert_equal initial_count, query.get_filtered_ids.size }
  end

  def test_get_filtered_ids_when_state_changes
    program = programs(:albers)
    time = 3.days.ago
    group = groups(:drafted_group_1)
    query_1 = NestedEsQuery::ActiveGroups.new(program, program.created_at, time)
    query_2 = NestedEsQuery::ActiveGroups.new(program, program.created_at, time - 1.day)
    assert_id_not_in_filtered_ids(query_1, group.id)
    assert_id_not_in_filtered_ids(query_2, group.id)

    state_change = group.state_changes.last
    date_id = time.utc.to_i / 1.day.to_i
    state_change.update_attributes(date_id: date_id, to_state: "#{Group::Status::ACTIVE}")
    reindex_documents(updated: group)
    assert_id_in_filtered_ids(query_1, group.id)
    assert_id_not_in_filtered_ids(query_2, group.id)

    state_change.update_attributes(date_id: date_id, to_state: "#{Group::Status::INACTIVE}")
    reindex_documents(updated: group)
    assert_id_in_filtered_ids(query_1, group.id)
    assert_id_not_in_filtered_ids(query_2, group.id)

    state_change.update_attributes(date_id: date_id, to_state: "#{Group::Status::CLOSED}")
    reindex_documents(updated: group)
    assert_id_not_in_filtered_ids(query_1, group.id)
    assert_id_not_in_filtered_ids(query_2, group.id)
  end
end