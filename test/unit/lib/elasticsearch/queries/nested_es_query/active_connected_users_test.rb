require_relative './test_helper'
require_relative './../../../../../test_helper'

class NestedEsQuery::ActiveConnectedUsersTest < ActiveSupport::TestCase
  include NestedEsQuery::TestHelper

  def test_initialize
    program = programs(:albers)
    time_now = Time.now
    query = NestedEsQuery::ActiveConnectedUsers.new(program, program.created_at, time_now)
    assert_equal program.created_at.to_i / 1.day.to_i, query.start_date_id
    assert_equal time_now.to_i / 1.day.to_i, query.end_date_id
    assert_equal program.all_user_ids, query.filterable_ids
    assert_nil query.role_query

    role = roles("#{program.id}_#{RoleConstants::MENTOR_NAME}")
    query = NestedEsQuery::ActiveConnectedUsers.new(program, time_now - 1.day, time_now, ids: ["filterable_ids"], role: role)
    assert_equal (time_now - 1.day).to_i / 1.day.to_i, query.start_date_id
    assert_equal time_now.to_i / 1.day.to_i, query.end_date_id
    assert_equal ["filterable_ids"], query.filterable_ids
    assert_equal_hash( { term: { "connection_membership_state_changes.role_id" => role.id } }, query.role_query)
  end

  def test_get_filtered_ids
    program = programs(:albers)
    query = NestedEsQuery::ActiveConnectedUsers.new(program, program.created_at, Time.now)
    assert_filtered_ids(query, users(:f_mentor, :robert, :mkr_student, :student_1, :student_2, :student_3, :student_4, :mentor_1, :not_requestable_mentor, :requestable_mentor).map(&:id))

    query.end_date_id = query.start_date_id
    assert_filtered_ids(query, [])
  end

  def test_get_filtered_ids_when_role_ids
    program = programs(:albers)
    role = roles("#{program.id}_#{RoleConstants::MENTOR_NAME}")
    query = NestedEsQuery::ActiveConnectedUsers.new(program, program.created_at, Time.now, role: role)
    assert_filtered_ids(query, users(:f_mentor, :robert, :mentor_1, :not_requestable_mentor, :requestable_mentor).map(&:id))

    query.end_date_id = query.start_date_id
    assert_filtered_ids(query, [])
  end

  def test_get_filtered_ids_when_state_changes
    program = programs(:albers)
    time = 3.days.ago
    admin_user = users(:f_admin)
    mentor_user = users(:f_mentor)
    query = NestedEsQuery::ActiveConnectedUsers.new(program, program.created_at, time)
    assert_id_not_in_filtered_ids(query, admin_user.id)

    state_transition = mentor_user.connection_membership_state_changes.first
    state_transition.user_id = admin_user.id
    state_transition.date_id = time.utc.to_i / 1.day.to_i
    state_transition.save!
    reindex_documents(updated: [mentor_user, admin_user])
    assert_id_in_filtered_ids(query, admin_user.id)

    query.end_date_id -= 1.day.to_i
    assert_id_not_in_filtered_ids(query, admin_user.id)

    info_hash = state_transition.info_hash
    info_hash[:user][:to_state] = User::Status::SUSPENDED
    state_transition.set_info(info_hash)
    state_transition.save!
    reindex_documents(updated: admin_user)
    assert_id_not_in_filtered_ids(query, admin_user.id)

    query.end_date_id += 1.day.to_i
    assert_id_not_in_filtered_ids(query, admin_user.id)
  end

  def test_get_filtered_ids_when_role_ids_and_state_changes
    program = programs(:albers)
    time = 3.days.from_now
    student_user = users(:f_student)
    mentor_user = users(:f_mentor)
    query = NestedEsQuery::ActiveConnectedUsers.new(program, program.created_at, time)
    assert_id_not_in_filtered_ids(query, student_user.id)

    state_transition = mentor_user.connection_membership_state_changes.first
    state_transition.user_id = student_user.id
    state_transition.date_id = time.utc.to_i / 1.day.to_i
    state_transition.save!
    reindex_documents(updated: [mentor_user, student_user])
    assert_id_in_filtered_ids(query, student_user.id)

    query.end_date_id -= 1.day.to_i
    assert_id_not_in_filtered_ids(query, student_user.id)

    info_hash = state_transition.info_hash
    info_hash[:user][:to_state] = User::Status::SUSPENDED
    state_transition.set_info(info_hash)
    state_transition.save!
    reindex_documents(updated: student_user)
    assert_id_not_in_filtered_ids(query, student_user.id)

    query.end_date_id += 1.day.to_i
    assert_id_not_in_filtered_ids(query, student_user.id)
  end
end