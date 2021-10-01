require_relative './test_helper'
require_relative './../../../../../test_helper'

class NestedEsQuery::NewRoleStateUsersTest < ActiveSupport::TestCase
  include NestedEsQuery::TestHelper

  def startup
    Object.const_set("CacheSource",
      Class.new do
        attr_accessor :newRoleStateUsersCache

        def initialize
          self.newRoleStateUsersCache = {}
        end
      end
    )
  end

  def shutdown
    Object.send(:remove_const, "CacheSource")
  end

  def test_initialize
    program = programs(:albers)
    time_now = Time.now
    query = NestedEsQuery::NewRoleStateUsers.new(program, program.created_at, time_now)
    assert_equal program.created_at.to_i / 1.day.to_i, query.start_date_id
    assert_equal time_now.to_i / 1.day.to_i, query.end_date_id
    assert_equal program.all_user_ids, query.filterable_ids
    assert_equal User::Status::ACTIVE, query.user_status
    assert_equal_unordered roles("#{program.id}_#{RoleConstants::MENTOR_NAME}", "#{program.id}_#{RoleConstants::STUDENT_NAME}").map(&:id), query.role_ids

    query = NestedEsQuery::NewRoleStateUsers.new(program, time_now - 1.day, time_now, user_status: User::Status::SUSPENDED, role_ids: ["role_ids"], ids: ["filterable_ids"])
    assert_equal (time_now - 1.day).to_i / 1.day.to_i, query.start_date_id
    assert_equal time_now.to_i / 1.day.to_i, query.end_date_id
    assert_equal ["filterable_ids"], query.filterable_ids
    assert_equal User::Status::SUSPENDED, query.user_status
    assert_equal ["role_ids"], query.role_ids
  end

  def test_get_filtered_ids
    program = programs(:albers)
    query = NestedEsQuery::NewRoleStateUsers.new(program, program.created_at, Time.now, include_new_role_users: true)
    assert_filtered_ids(query, program.all_user_ids - users(:f_admin, :f_user).map(&:id))

    query.end_date_id = query.start_date_id
    assert_filtered_ids(query, [])
  end

  def test_get_filtered_ids_for_suspended_when_cache_source_present
    program = programs(:psg)
    cache_source = CacheSource.new
    query = NestedEsQuery::NewRoleStateUsers.new(program, program.created_at, Time.now, user_status: User::Status::SUSPENDED, cache_source: cache_source)
    assert_filtered_ids(query, [users(:inactive_user).id])
    cache = cache_source.newRoleStateUsersCache
    assert_equal_unordered users(:psg_student1, :psg_student2, :psg_student3, :psg_mentor, :psg_mentor1, :psg_mentor2, :psg_mentor3, :inactive_user, :psg_remove).map(&:id), cache[query.send(:get_cache_key, :roles)][:roles_count]
    assert_equal [users(:inactive_user).id], cache[query.send(:get_cache_key, :state)][:state_count]
    assert_empty cache[query.send(:get_cache_key, :roles)][:before_roles_count]
    assert_empty cache[query.send(:get_cache_key, :state)][:before_state_count]

    User.expects(:get_inner_hits_map).never
    query.end_date_id = query.start_date_id
    assert_filtered_ids(query, [])
  end

  def test_get_filtered_ids_for_active
    program = programs(:albers)
    time_1 = 3.days.from_now
    time_2 = 6.days.from_now
    query_1 = NestedEsQuery::NewRoleStateUsers.new(program, program.created_at, time_1, include_new_role_users: true)
    query_2 = NestedEsQuery::NewRoleStateUsers.new(program, time_1, time_2, include_new_role_users: true)
    initial_count_1 = nil
    initial_count_2 = nil
    query_executor(query_1) { initial_count_1 = query_1.get_filtered_ids.size }
    query_executor(query_2) { initial_count_2 = query_2.get_filtered_ids.size }

    user = users(:pending_user)
    state_transition = user.state_transitions.first
    state_transition.date_id = (time_1.utc.to_i / 1.day.to_i) + 1
    state_transition.save!
    reindex_documents(updated: user)
    query_executor(query_1) { assert_equal initial_count_1 - 1, query_1.get_filtered_ids.size }
    query_executor(query_2) { assert_equal initial_count_2 + 1, query_2.get_filtered_ids.size }
  end

  def test_get_filtered_ids_for_active_with_state_and_roles_changes
    program = programs(:albers)
    time_1 = 3.days.from_now
    time_2 = 6.days.from_now
    date_id = (time_1.utc.to_i / 1.day.to_i)
    role_ids = [roles("#{program.id}_#{RoleConstants::MENTOR_NAME}").id]
    query_1 = NestedEsQuery::NewRoleStateUsers.new(program, program.created_at, time_1, role_ids: role_ids, include_new_role_users: true)
    query_2 = NestedEsQuery::NewRoleStateUsers.new(program, time_1, time_2, role_ids: role_ids, include_new_role_users: true)
    initial_count_1 = nil
    initial_count_2 = nil
    query_executor(query_1) { initial_count_1 = query_1.get_filtered_ids.size }
    query_executor(query_2) { initial_count_2 = query_2.get_filtered_ids.size }

    user_1 = users(:f_student)
    info_hash = user_1.state_transitions.first.info_hash
    info_hash[:role][:to] << role_ids[0]
    info_hash[:state][:to] = User::Status::SUSPENDED
    new_state_transition = user_1.state_transitions.new(date_id: date_id + 1)
    new_state_transition.set_info(info_hash)
    new_state_transition.save!
    reindex_documents(updated: user_1)
    query_executor(query_1) { assert_equal initial_count_1, query_1.get_filtered_ids.size }
    query_executor(query_2) { assert_equal initial_count_2 + 1, query_2.get_filtered_ids.size }

    user_2 = users(:mentor_0)
    state_transition = user_2.state_transitions.first
    info_hash = state_transition.info_hash
    info_hash[:state][:to] = User::Status::SUSPENDED
    state_transition.set_info(info_hash)
    state_transition.save!
    reindex_documents(updated: user_2)
    query_executor(query_1) { assert_equal initial_count_1, query_1.get_filtered_ids.size }
    query_executor(query_2) { assert_equal initial_count_2 + 1, query_2.get_filtered_ids.size }

    info_hash[:state][:to] = User::Status::ACTIVE
    new_state_transition = user_2.state_transitions.new(date_id: date_id + 1)
    new_state_transition.set_info(info_hash)
    new_state_transition.save!
    reindex_documents(updated: user_2)
    query_executor(query_1) { assert_equal initial_count_1, query_1.get_filtered_ids.size }
    query_executor(query_2) { assert_equal initial_count_2 + 2, query_2.get_filtered_ids.size }
  end

  def test_get_filtered_ids_for_suspended_with_state_and_roles_changes
    program = programs(:albers)
    time = 3.days.ago
    date_id = time.utc.to_i / 1.day.to_i
    role_ids = [roles("#{program.id}_#{RoleConstants::MENTOR_NAME}").id]
    query_1 = NestedEsQuery::NewRoleStateUsers.new(program, program.created_at, time, user_status: User::Status::SUSPENDED, role_ids: role_ids)
    query_2 = NestedEsQuery::NewRoleStateUsers.new(program, time, Time.now, user_status: User::Status::SUSPENDED, role_ids: role_ids)
    initial_count_1 = nil
    initial_count_2 = nil
    query_executor(query_1) { initial_count_1 = query_1.get_filtered_ids.size }
    query_executor(query_2) { initial_count_2 = query_2.get_filtered_ids.size }

    user_1 = users(:pending_user)
    info_hash = user_1.state_transitions.first.info_hash
    info_hash[:state][:to] = User::Status::SUSPENDED
    new_state_transition = user_1.state_transitions.new(date_id: date_id + 1)
    new_state_transition.set_info(info_hash)
    new_state_transition.save!
    reindex_documents(updated: user_1)
    query_executor(query_1) { assert_equal initial_count_1, query_1.get_filtered_ids.size }
    query_executor(query_2) { assert_equal initial_count_2 + 1, query_2.get_filtered_ids.size }

    user_2 = users(:f_student)
    state_transition = user_2.state_transitions.first
    info_hash = state_transition.info_hash
    info_hash[:state][:to] = User::Status::SUSPENDED
    state_transition.set_info(info_hash)
    state_transition.save!
    reindex_documents(updated: user_2)
    query_executor(query_1) { assert_equal initial_count_1, query_1.get_filtered_ids.size }
    query_executor(query_2) { assert_equal initial_count_2 + 1, query_2.get_filtered_ids.size }

    info_hash[:role][:to] << role_ids[0]
    new_state_transition = user_2.state_transitions.new(date_id: date_id + 1)
    new_state_transition.set_info(info_hash)
    new_state_transition.save!
    reindex_documents(updated: user_2)
    query_executor(query_1) { assert_equal initial_count_1, query_1.get_filtered_ids.size }
    query_executor(query_2) { assert_equal initial_count_2 + 2, query_2.get_filtered_ids.size }
  end

  def test_cache
    program = programs(:albers)
    time_now = Time.now

    query = NestedEsQuery::NewRoleStateUsers.new(program, program.created_at, time_now)
    assert_false query.send(:is_caching_enabled?)
    assert_nil query.send(:write_to_cache, "k", "v")
    assert_nil query.send(:cache_lookup, "k")

    query = NestedEsQuery::NewRoleStateUsers.new(program, program.created_at, time_now, cache_source: Object.new)
    assert_false query.send(:is_caching_enabled?)
    assert_nil query.send(:write_to_cache, "k", "v")
    assert_nil query.send(:cache_lookup, "k")

    cache_source = CacheSource.new
    query = NestedEsQuery::NewRoleStateUsers.new(program, program.created_at, time_now, cache_source: cache_source)
    assert query.send(:is_caching_enabled?)
    assert_equal "v", query.send(:write_to_cache, "k", "v")
    assert_equal "v", query.send(:cache_lookup, "k")
    assert_equal_hash( { "k" => "v" }, cache_source.newRoleStateUsersCache)
  end

  def test_get_cache_key
    program = programs(:albers)
    time_now = Time.now
    mentor_role_id = roles("#{program.id}_#{RoleConstants::MENTOR_NAME}").id
    student_role_id = roles("#{program.id}_#{RoleConstants::STUDENT_NAME}").id

    query = NestedEsQuery::NewRoleStateUsers.new(program, program.created_at, time_now, cache_source: CacheSource.new)
    assert_equal "#{User::Status::ACTIVE}_#{query.start_date_id}_#{query.end_date_id}", query.send(:get_cache_key, :state)
    assert_equal "#{mentor_role_id}_#{student_role_id}_#{query.start_date_id}_#{query.end_date_id}", query.send(:get_cache_key, :roles)

    query = NestedEsQuery::NewRoleStateUsers.new(program, program.created_at, time_now, role_ids: [student_role_id], user_status: User::Status::SUSPENDED, cache_source: CacheSource.new)
    assert_equal "#{User::Status::SUSPENDED}_#{query.start_date_id}_#{query.end_date_id}", query.send(:get_cache_key, :state)
    assert_equal "#{student_role_id}_#{query.start_date_id}_#{query.end_date_id}", query.send(:get_cache_key, :roles)
  end
end