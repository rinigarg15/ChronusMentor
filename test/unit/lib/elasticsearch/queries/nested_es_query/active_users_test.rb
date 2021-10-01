require_relative './test_helper'
require_relative './../../../../../test_helper'

class NestedEsQuery::ActiveUsersTest < ActiveSupport::TestCase
  include NestedEsQuery::TestHelper

  def test_initialize
    program = programs(:albers)
    time_now = Time.now
    query = NestedEsQuery::ActiveUsers.new(program, program.created_at, time_now)
    assert_equal program.created_at.to_i / 1.day.to_i, query.start_date_id
    assert_equal time_now.to_i / 1.day.to_i, query.end_date_id
    assert_equal program.all_user_ids, query.filterable_ids
    assert_equal User::Status::ACTIVE, query.user_status
    assert_equal_unordered roles("#{program.id}_#{RoleConstants::MENTOR_NAME}", "#{program.id}_#{RoleConstants::STUDENT_NAME}").map(&:id), query.role_ids

    query = NestedEsQuery::ActiveUsers.new(program, time_now - 1.day, time_now, include_unpublished: true, role_ids: ["role_ids"], ids: ["filterable_ids"])
    assert_equal (time_now - 1.day).to_i / 1.day.to_i, query.start_date_id
    assert_equal time_now.to_i / 1.day.to_i, query.end_date_id
    assert_equal ["filterable_ids"], query.filterable_ids
    assert_equal [User::Status::ACTIVE, User::Status::PENDING], query.user_status
    assert_equal ["role_ids"], query.role_ids
  end

  def test_get_filtered_ids
    program = programs(:albers)
    query = NestedEsQuery::ActiveUsers.new(program, program.created_at, Time.now)
    assert_filtered_ids(query, program.all_user_ids - users(:f_admin, :f_user, :pending_user).map(&:id))

    query.end_date_id = query.start_date_id
    assert_filtered_ids(query, [])

    query = NestedEsQuery::ActiveUsers.new(program, program.created_at, Time.now, include_unpublished: true)
    assert_filtered_ids(query, program.all_user_ids - users(:f_admin, :f_user).map(&:id))
  end

  def test_get_filtered_ids_when_role_ids
    program = programs(:albers)
    role = roles("#{program.id}_#{RoleConstants::MENTOR_NAME}")
    query = NestedEsQuery::ActiveUsers.new(program, program.created_at, Time.now, role_ids: [role.id])
    assert_filtered_ids(query, program.mentor_users.pluck(:id) - [users(:pending_user).id])

    query.end_date_id = query.start_date_id
    assert_filtered_ids(query, [])
  end

  def test_get_filtered_ids_when_state_changes
    program = programs(:albers)
    time = 3.days.ago
    user = users(:pending_user)
    state_transition = user.state_transitions.first
    query = NestedEsQuery::ActiveUsers.new(program, program.created_at, time)
    assert_id_not_in_filtered_ids(query, user.id)

    state_transition.date_id = time.utc.to_i / 1.day.to_i
    state_transition.save!
    reindex_documents(updated: user)
    assert_id_not_in_filtered_ids(query, user.id)

    info_hash = state_transition.info_hash
    info_hash[:state][:to] = User::Status::ACTIVE
    state_transition.set_info(info_hash)
    state_transition.save!
    reindex_documents(updated: user)
    assert_id_in_filtered_ids(query, user.id)

    query.end_date_id -= 1.day.to_i
    assert_id_not_in_filtered_ids(query, user.id)

    query = NestedEsQuery::ActiveUsers.new(program, program.created_at, time, ids: program.users.active.pluck(:id))
    assert_id_not_in_filtered_ids(query, user.id)
  end

  def test_get_filtered_ids_when_roles_change
    program = programs(:albers)
    mentor_role = roles("#{program.id}_#{RoleConstants::MENTOR_NAME}")
    time = 3.days.ago
    user = users(:f_student)
    state_transition = user.state_transitions.first
    query = NestedEsQuery::ActiveUsers.new(program, program.created_at, time, role_ids: [mentor_role.id])
    assert_id_not_in_filtered_ids(query, user.id)

    state_transition.date_id = time.utc.to_i / 1.day.to_i
    state_transition.save!
    reindex_documents(updated: user)
    assert_id_not_in_filtered_ids(query, user.id)

    info_hash = state_transition.info_hash
    info_hash[:role][:to] << mentor_role.id
    state_transition.set_info(info_hash)
    state_transition.save!
    reindex_documents(updated: user)
    assert_id_in_filtered_ids(query, user.id)

    query.end_date_id -= 1.day.to_i
    assert_id_not_in_filtered_ids(query, user.id)

    query = NestedEsQuery::ActiveUsers.new(program, program.created_at, time, ids: program.users.active.pluck(:id) - [user.id])
    assert_id_not_in_filtered_ids(query, user.id)
  end
end