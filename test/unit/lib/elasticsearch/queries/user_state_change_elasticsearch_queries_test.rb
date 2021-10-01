require_relative './../../../../test_helper'

class UserStateChangeElasticsearchQueriesTest < ActiveSupport::TestCase
  def test_get_user_state_changes_per_day
    program = programs(:albers)
    mentoring_role_ids = program.mentoring_role_ids
    end_time =  program.created_at + 99.days
    user_ids = program.users.pluck(:id)
    deleted_usc = users(:f_admin).state_transitions.to_a
    reindex_documents(deleted: deleted_usc)
    users(:f_admin).state_transitions.destroy_all

    uscs = UserStateChange.where("user_id in (?) AND created_at <= ?", user_ids, end_time)
    total_additions = 0
    total_removals = 0
    uscs.each do |usc|
      total_additions += 1 if ((usc.from_state != User::Status::ACTIVE) || (usc.from_roles & mentoring_role_ids).size == 0) && ((usc.to_state == User::Status::ACTIVE) && (usc.to_roles & mentoring_role_ids).size > 0)

      total_removals += 1 if ((usc.to_state != User::Status::ACTIVE) || (usc.to_roles & mentoring_role_ids).size == 0) && (usc.from_state == User::Status::ACTIVE) && (usc.from_roles & mentoring_role_ids).size > 0
    end

    additions_per_day = UserStateChange.get_user_state_changes_per_day_for_active_users(program, nil, end_time).response.aggregations.additions_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}
    removals_per_day = UserStateChange.get_user_state_changes_per_day_for_active_users(program, nil, end_time).response.aggregations.removals_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}

    assert_equal 100, additions_per_day.size
    assert_equal total_additions, additions_per_day.sum
    assert_equal 100, removals_per_day.size
    assert_equal total_removals, removals_per_day.sum

    time = end_time - 5.days
    date_id = time.utc.to_i/1.day.to_i

    usc_1 = users(:f_admin).state_transitions.new(:date_id => date_id)
    usc_1.set_info({state: {from: nil, to: User::Status::ACTIVE}, role: {from: [mentoring_role_ids[0]], to: [mentoring_role_ids[0]]}})
    usc_1.set_connection_membership_info({role: {from: nil, to: nil}})
    usc_1.save!

    usc_1_1 = users(:f_admin).state_transitions.new(:date_id => date_id)
    usc_1_1.set_info({state: {from: nil, to: User::Status::ACTIVE}, role: {from: [], to: []}})
    usc_1_1.set_connection_membership_info({role: {from: nil, to: nil}})
    usc_1_1.save!

    usc_2 = users(:f_admin).state_transitions.new(:date_id => date_id)
    usc_2.set_info({state: {from: User::Status::ACTIVE, to: nil}, role: {}})
    usc_2.set_connection_membership_info({role: {from: nil, to: nil}})
    usc_2.save!

    usc_2_1 = users(:f_admin).state_transitions.new(:date_id => date_id)
    usc_2_1.set_info({state: {from: User::Status::ACTIVE, to: nil}, role: {from: [mentoring_role_ids[0]], to: []}})
    usc_2_1.set_connection_membership_info({role: {from: nil, to: nil}})
    usc_2_1.save!

    usc_3 = users(:f_admin).state_transitions.new(:date_id => date_id)
    usc_3.set_info({state: {from: nil, to: User::Status::PENDING}, role: {from: [mentoring_role_ids[0]], to: [mentoring_role_ids[0]]}})
    usc_3.set_connection_membership_info({role: {from: nil, to: nil}})
    usc_3.save!

    usc_4 = users(:f_admin).state_transitions.new(:date_id => date_id)
    usc_4.set_info({state: {from: User::Status::PENDING, to: User::Status::ACTIVE}, role: {from: [mentoring_role_ids[0]], to: [mentoring_role_ids[0]]}})
    usc_4.set_connection_membership_info({role: {from: nil, to: nil}})
    usc_4.save!

    usc_5 = users(:f_admin).state_transitions.new(:date_id => date_id)
    usc_5.set_info({state: {from: User::Status::ACTIVE, to: User::Status::SUSPENDED}, role: {from: [mentoring_role_ids[0]], to: [mentoring_role_ids[0]]}})
    usc_5.set_connection_membership_info({role: {from: nil, to: nil}})
    usc_5.save!

    reindex_documents(created: [usc_1, usc_1_1, usc_2, usc_2_1, usc_3, usc_4, usc_5])
    assert_equal additions_per_day[-6] + 2, UserStateChange.get_user_state_changes_per_day_for_active_users(program, nil, end_time).response.aggregations.additions_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}[-6]
    assert_equal removals_per_day[-6] + 2, UserStateChange.get_user_state_changes_per_day_for_active_users(program, nil, end_time).response.aggregations.removals_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}[-6]
    assert_equal additions_per_day, UserStateChange.get_user_state_changes_per_day_for_active_users(program, user_ids - [users(:f_admin).id], end_time).response.aggregations.additions_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}
  end

  def test_get_user_state_changes_per_day_per_role
    program = programs(:albers)
    role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    end_time =  program.created_at + 99.days
    user_ids = program.users.pluck(:id)
    deleted_usc = users(:f_admin).state_transitions.to_a
    reindex_documents(deleted: deleted_usc)
    users(:f_admin).state_transitions.destroy_all

    uscs = UserStateChange.where("user_id in (?) AND created_at <= ?", user_ids, end_time)
    total_additions = 0
    total_removals = 0
    uscs.each do |usc|
      total_additions += 1 if ((usc.from_state != User::Status::ACTIVE) || !usc.from_roles.include?(role.id)) && ((usc.to_state == User::Status::ACTIVE) && usc.to_roles.include?(role.id))
      total_removals += 1 if ((usc.to_state != User::Status::ACTIVE) || !usc.to_roles.include?(role.id)) && (usc.from_state == User::Status::ACTIVE) && usc.from_roles.include?(role.id)
    end

    additions_per_day = UserStateChange.get_user_state_changes_per_day_per_role(program, nil, end_time, role).response.aggregations.additions_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}
    removals_per_day = UserStateChange.get_user_state_changes_per_day_per_role(program, nil, end_time, role).response.aggregations.removals_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}

    assert_equal 100, additions_per_day.size
    assert_equal total_additions, additions_per_day.sum
    assert_equal 100, removals_per_day.size
    assert_equal total_removals, removals_per_day.sum

    time = end_time - 5.days
    date_id = time.utc.to_i/1.day.to_i

    usc_1_1 = users(:f_admin).state_transitions.new(:date_id => date_id)
    usc_1_1.set_info({state: {from: nil, to: User::Status::ACTIVE}, role: {from: [role.id, 41400], to: [role.id, 43542]}})
    usc_1_1.set_connection_membership_info({role: {from: nil, to: nil}})
    usc_1_1.save!

    usc_1_2 = users(:f_admin).state_transitions.new(:date_id => date_id)
    usc_1_2.set_info({state: {from: User::Status::ACTIVE, to: User::Status::ACTIVE}, role: {from: [353453], to: [role.id]}})
    usc_1_2.set_connection_membership_info({role: {from: nil, to: nil}})
    usc_1_2.save!

    usc_2_1 = users(:f_admin).state_transitions.new(:date_id => date_id)
    usc_2_1.set_info({state: {from: User::Status::ACTIVE, to: nil}, role: {from: [role.id, 41400], to: [role.id, 43542]}})
    usc_2_1.set_connection_membership_info({role: {from: nil, to: nil}})
    usc_2_1.save!

    usc_2_2 = users(:f_admin).state_transitions.new(:date_id => date_id)
    usc_2_2.set_info({state: {from: User::Status::ACTIVE, to: User::Status::ACTIVE}, role: {to: [41400], from: [role.id, 43542]}})
    usc_2_2.set_connection_membership_info({role: {from: nil, to: nil}})
    usc_2_2.save!

    usc_3_1 = users(:f_admin).state_transitions.new(:date_id => date_id)
    usc_3_1.set_info({state: {from: nil, to: User::Status::PENDING}, role: {from: [role.id, 41400], to: [role.id, 43542]}})
    usc_3_1.set_connection_membership_info({role: {from: nil, to: nil}})
    usc_3_1.save!

    usc_3_2 = users(:f_admin).state_transitions.new(:date_id => date_id)
    usc_3_2.set_info({state: {from: User::Status::PENDING, to: User::Status::PENDING}, role: {from: [353453], to: [role.id]}})
    usc_3_2.set_connection_membership_info({role: {from: nil, to: nil}})
    usc_3_2.save!

    usc_4_1 = users(:f_admin).state_transitions.new(:date_id => date_id)
    usc_4_1.set_info({state: {from: User::Status::PENDING, to: nil}, role: {from: [role.id, 41400], to: [role.id, 43542]}})
    usc_4_1.set_connection_membership_info({role: {from: nil, to: nil}})
    usc_4_1.save!

    usc_4_2 = users(:f_admin).state_transitions.new(:date_id => date_id)
    usc_4_2.set_info({state: {from: User::Status::PENDING, to: User::Status::PENDING}, role: {to: [41400], from: [role.id, 43542]}})
    usc_4_2.set_connection_membership_info({role: {from: nil, to: nil}})
    usc_4_2.save!

    usc_5_1 = users(:f_admin).state_transitions.new(:date_id => date_id)
    usc_5_1.set_info({state: {from: User::Status::ACTIVE, to: User::Status::PENDING}, role: {from: [role.id], to: [role.id]}})
    usc_5_1.set_connection_membership_info({role: {from: nil, to: nil}})
    usc_5_1.save!

    usc_5_2 = users(:f_admin).state_transitions.new(:date_id => date_id)
    usc_5_2.set_info({state: {from: User::Status::PENDING, to: User::Status::ACTIVE}, role: {to: [role.id], from: [role.id, 43542]}})
    usc_5_2.set_connection_membership_info({role: {from: nil, to: nil}})
    usc_5_2.save!

    reindex_documents(created: [usc_1_1, usc_1_2, usc_2_1, usc_2_2, usc_3_1, usc_3_2, usc_4_1, usc_4_2, usc_5_1, usc_5_2])
    assert_equal additions_per_day[-6] + 3, UserStateChange.get_user_state_changes_per_day_per_role(program, nil, end_time, role).response.aggregations.additions_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}[-6]
    assert_equal removals_per_day[-6] + 3, UserStateChange.get_user_state_changes_per_day_per_role(program, nil, end_time, role).response.aggregations.removals_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}[-6]
    assert_equal additions_per_day, UserStateChange.get_user_state_changes_per_day_per_role(program, user_ids - [users(:f_admin).id], end_time, role).response.aggregations.additions_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}
    assert_equal removals_per_day, UserStateChange.get_user_state_changes_per_day_per_role(program, user_ids - [users(:f_admin).id], end_time, role).response.aggregations.removals_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}

  end


  def test_get_active_connected_users_per_day
    program = programs(:albers)
    end_time =  program.created_at + 99.days
    user_ids = program.users.pluck(:id)

    start_date_id = program.created_at.utc.to_i/1.day.to_i
    end_date_id = end_time.utc.to_i/1.day.to_i

    user_2 = users(:f_student)
    user_2_transition = user_2.state_transitions.first
    transition_1 = user_2.state_transitions.new(date_id: user_2_transition.date_id+3)
    transition_1.set_info({state: {from: User::Status::ACTIVE, to: User::Status::ACTIVE}, role: {from: user_2_transition.info_hash[:role][:from], to: user_2_transition.info_hash[:role][:to]}})
    transition_1.set_connection_membership_info({role: {from_role: [], to_role: [user_2_transition.info_hash[:role][:to].first]}})
    transition_1.save!
    transition_2 = user_2.state_transitions.new(date_id: user_2_transition.date_id+5)
    transition_2.set_info({state: {from: User::Status::ACTIVE, to: User::Status::SUSPENDED}, role: {from: user_2_transition.info_hash[:role][:from], to: user_2_transition.info_hash[:role][:to]}})
    transition_2.set_connection_membership_info({role: {from_role: [user_2_transition.info_hash[:role][:to].first], to_role: [user_2_transition.info_hash[:role][:to].first]}})
    transition_2.save!
    transition_3 = user_2.state_transitions.new(date_id: user_2_transition.date_id+7)
    transition_3.set_info({state: {from: User::Status::SUSPENDED, to: User::Status::ACTIVE}, role: {from: user_2_transition.info_hash[:role][:from], to: user_2_transition.info_hash[:role][:to]}})
    transition_3.set_connection_membership_info({role: {from_role: [user_2_transition.info_hash[:role][:to].first], to_role: [user_2_transition.info_hash[:role][:to].first]}})
    transition_3.save!
    transition_4 = user_2.state_transitions.new(date_id: user_2_transition.date_id+9)
    transition_4.set_info({state: {from: User::Status::ACTIVE, to: User::Status::ACTIVE}, role: {from: user_2_transition.info_hash[:role][:from], to: user_2_transition.info_hash[:role][:to]}})
    transition_4.set_connection_membership_info({role: {from_role: [user_2_transition.info_hash[:role][:to].first], to_role: []}})
    transition_4.save!
    transition_5 = user_2.state_transitions.new(date_id: user_2_transition.date_id+10)
    transition_5.set_info({state: {from: User::Status::ACTIVE, to: User::Status::ACTIVE}, role: {from: user_2_transition.info_hash[:role][:from], to: user_2_transition.info_hash[:role][:to]}})
    transition_5.set_connection_membership_info({role: {from_role: [], to_role: [user_2_transition.info_hash[:role][:to].first]}})
    transition_5.save!
    transition_6 = user_2.state_transitions.new(date_id: user_2_transition.date_id+12)
    transition_6.set_info({state: {from: User::Status::ACTIVE, to: User::Status::SUSPENDED}, role: {from: user_2_transition.info_hash[:role][:from], to: user_2_transition.info_hash[:role][:to]}})
    transition_6.set_connection_membership_info({role: {from_role: [user_2_transition.info_hash[:role][:to].first], to_role: []}})
    transition_6.save!

    uscs = UserStateChange.where("user_id in (?) AND created_at <= ?", user_ids, end_time)
    reindex_documents(created: [transition_1, transition_2, transition_3, transition_4, transition_5, transition_6])

    total_additions = Array.new(end_date_id - start_date_id + 1) { 0 }
    total_removals = Array.new(end_date_id - start_date_id + 1) { 0 }
    total_additions_except_user_2 = Array.new(end_date_id - start_date_id + 1) { 0 }
    total_removals_except_user_2 = Array.new(end_date_id - start_date_id + 1) { 0 }
    uscs.each do |usc|
      if usc.from_state != User::Status::ACTIVE && usc.to_state == User::Status::ACTIVE && usc.connection_membership_to_roles != nil
        total_additions[usc.date_id - start_date_id] += 1
        total_additions_except_user_2[usc.date_id - start_date_id] += 1 if usc.user_id != user_2.id
      elsif usc.to_state == User::Status::ACTIVE && usc.connection_membership_to_roles != nil && usc.connection_membership_from_roles == nil
        total_additions[usc.date_id - start_date_id] += 1
        total_additions_except_user_2[usc.date_id - start_date_id] += 1 if usc.user_id != user_2.id
      elsif usc.from_state == User::Status::ACTIVE && usc.to_state != User::Status::ACTIVE && usc.connection_membership_from_roles != nil
        total_removals[usc.date_id - start_date_id] += 1
        total_removals_except_user_2[usc.date_id - start_date_id] += 1 if usc.user_id != user_2.id
      elsif usc.from_state == User::Status::ACTIVE && usc.connection_membership_to_roles == nil && usc.connection_membership_from_roles != nil
        total_removals[usc.date_id - start_date_id] += 1
        total_removals_except_user_2[usc.date_id - start_date_id] += 1 if usc.user_id != user_2.id
      end
    end

    additions_per_day = UserStateChange.get_active_connected_users_per_day(program, nil, end_time).response.aggregations.additions_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}
    removals_per_day = UserStateChange.get_active_connected_users_per_day(program, nil, end_time).response.aggregations.removals_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}
    additions_per_day_except_user_2 = UserStateChange.get_active_connected_users_per_day(program,  user_ids - [user_2.id], end_time).response.aggregations.additions_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}
    removals_per_day_except_user_2 = UserStateChange.get_active_connected_users_per_day(program, user_ids - [user_2.id], end_time).response.aggregations.removals_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}

    assert_equal total_additions, additions_per_day
    assert_equal total_removals, removals_per_day
    assert_equal total_additions_except_user_2, additions_per_day_except_user_2
    assert_equal total_removals_except_user_2, removals_per_day_except_user_2
  end


  def test_get_active_connected_users_per_day_per_role
    program = programs(:albers)
    end_time =  program.created_at + 99.days
    user_ids = program.users.pluck(:id)
    role_mentor = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    role_student = program.roles.find_by(name: RoleConstants::STUDENT_NAME)

    start_date_id = program.created_at.utc.to_i/1.day.to_i
    end_date_id = end_time.utc.to_i/1.day.to_i

    user_2 = users(:f_student)
    user_2_transition = user_2.state_transitions.first
    transition_1 = user_2.state_transitions.new(date_id: user_2_transition.date_id+3)
    transition_1.set_info({state: {from: User::Status::ACTIVE, to: User::Status::ACTIVE}, role: {from: user_2_transition.info_hash[:role][:from], to: user_2_transition.info_hash[:role][:to]}})
    transition_1.set_connection_membership_info({role: {from_role: [], to_role: [role_mentor.id]}})
    transition_1.save!
    transition_2 = user_2.state_transitions.new(date_id: user_2_transition.date_id+5)
    transition_2.set_info({state: {from: User::Status::ACTIVE, to: User::Status::SUSPENDED}, role: {from: user_2_transition.info_hash[:role][:from], to: user_2_transition.info_hash[:role][:to]}})
    transition_2.set_connection_membership_info({role: {from_role: [role_mentor.id], to_role: [role_mentor.id]}})
    transition_2.save!
    transition_3 = user_2.state_transitions.new(date_id: user_2_transition.date_id+7)
    transition_3.set_info({state: {from: User::Status::SUSPENDED, to: User::Status::ACTIVE}, role: {from: user_2_transition.info_hash[:role][:from], to: user_2_transition.info_hash[:role][:to]}})
    transition_3.set_connection_membership_info({role: {from_role: [role_mentor.id], to_role: [role_mentor.id]}})
    transition_3.save!
    transition_4 = user_2.state_transitions.new(date_id: user_2_transition.date_id+8)
    transition_4.set_info({state: {from: User::Status::ACTIVE, to: User::Status::ACTIVE}, role: {from: user_2_transition.info_hash[:role][:from], to: user_2_transition.info_hash[:role][:to]}})
    transition_4.set_connection_membership_info({role: {from_role: [role_mentor.id], to_role: [role_mentor.id, role_student.id]}})
    transition_4.save!
    transition_5 = user_2.state_transitions.new(date_id: user_2_transition.date_id+9)
    transition_5.set_info({state: {from: User::Status::ACTIVE, to: User::Status::ACTIVE}, role: {from: user_2_transition.info_hash[:role][:from], to: user_2_transition.info_hash[:role][:to]}})
    transition_5.set_connection_membership_info({role: {from_role: [role_mentor.id, role_student.id], to_role: [role_student.id]}})
    transition_5.save!
    transition_6 = user_2.state_transitions.new(date_id: user_2_transition.date_id+9)
    transition_6.set_info({state: {from: User::Status::ACTIVE, to: User::Status::SUSPENDED}, role: {from: user_2_transition.info_hash[:role][:from], to: user_2_transition.info_hash[:role][:to]}})
    transition_6.set_connection_membership_info({role: {from_role: [role_student.id], to_role: []}})
    transition_6.save!

    uscs = UserStateChange.where("user_id in (?) AND created_at <= ?", user_ids, end_time)
    reindex_documents(created: [transition_1, transition_2, transition_3, transition_4, transition_5, transition_6])

    total_additions = Array.new(end_date_id - start_date_id + 1) { 0 }
    total_removals = Array.new(end_date_id - start_date_id + 1) { 0 }
    total_additions_except_user_2 = Array.new(end_date_id - start_date_id + 1) { 0 }
    total_removals_except_user_2 = Array.new(end_date_id - start_date_id + 1) { 0 }
    get_additions_removals_for_active_connected_users(uscs, role_mentor, total_additions, total_removals, start_date_id, user_2.id, total_additions_except_user_2, total_removals_except_user_2)

    additions_per_day = UserStateChange.get_active_connected_users_per_day_per_role(program, nil, end_time, role_mentor).response.aggregations.additions_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}
    removals_per_day = UserStateChange.get_active_connected_users_per_day_per_role(program, nil, end_time, role_mentor).response.aggregations.removals_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}
    additions_per_day_except_user_2 = UserStateChange.get_active_connected_users_per_day_per_role(program, user_ids - [user_2.id], end_time, role_mentor).response.aggregations.additions_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}
    removals_per_day_except_user_2 = UserStateChange.get_active_connected_users_per_day_per_role(program, user_ids - [user_2.id], end_time, role_mentor).response.aggregations.removals_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}

    assert_equal total_additions, additions_per_day
    assert_equal total_removals, removals_per_day
    assert_equal total_additions_except_user_2, additions_per_day_except_user_2
    assert_equal total_removals_except_user_2, removals_per_day_except_user_2

    total_additions = Array.new(end_date_id - start_date_id + 1) { 0 }
    total_removals = Array.new(end_date_id - start_date_id + 1) { 0 }
    total_additions_except_user_2 = Array.new(end_date_id - start_date_id + 1) { 0 }
    total_removals_except_user_2 = Array.new(end_date_id - start_date_id + 1) { 0 }
    get_additions_removals_for_active_connected_users(uscs, role_student, total_additions, total_removals, start_date_id, user_2.id, total_additions_except_user_2, total_removals_except_user_2)

    additions_per_day = UserStateChange.get_active_connected_users_per_day_per_role(program, nil, end_time, role_student).response.aggregations.additions_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}
    removals_per_day = UserStateChange.get_active_connected_users_per_day_per_role(program, nil, end_time, role_student).response.aggregations.removals_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}
    additions_per_day_except_user_2 = UserStateChange.get_active_connected_users_per_day_per_role(program, user_ids - [user_2.id], end_time, role_student).response.aggregations.additions_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}
    removals_per_day_except_user_2 = UserStateChange.get_active_connected_users_per_day_per_role(program, user_ids - [user_2.id], end_time, role_student).response.aggregations.removals_per_day.date_aggregation.buckets.map{|k, v| v.doc_count}
    assert_equal total_additions, additions_per_day
    assert_equal total_removals, removals_per_day
    assert_equal total_additions_except_user_2, additions_per_day_except_user_2
    assert_equal total_removals_except_user_2, removals_per_day_except_user_2
  end

  def test_get_dates_and_user_ids
    program  = programs(:albers)
    start_date_id = program.created_at.utc.to_i/1.day.to_i
    end_time = program.created_at - 5.days
    end_date_id = end_time.utc.to_i/1.day.to_i
    assert_equal [start_date_id, start_date_id, {}], UserStateChange.send(:get_dates_and_user_ids, program, nil, end_time)
    end_time = program.created_at + 5.days
    end_date_id = end_time.utc.to_i/1.day.to_i
    assert_equal [start_date_id, end_date_id, {}], UserStateChange.send(:get_dates_and_user_ids, program, nil, end_time)
  end

  private

  def array_includes?(array, value)
    return false if array.nil?
    return array.include?(value)
  end

  def get_additions_removals_for_active_connected_users(user_state_changes, role, total_additions, total_removals, offset, ignore_user_id = nil, total_additions_except_user = nil, total_removals_except_user = nil)
    user_state_changes.each do |usc|
      if usc.from_state != User::Status::ACTIVE && usc.to_state == User::Status::ACTIVE && array_includes?(usc.connection_membership_to_roles, role.id)
        total_additions[usc.date_id - offset] += 1
        total_additions_except_user[usc.date_id - offset] += 1 if !total_additions_except_user.nil? && usc.user_id != ignore_user_id
      elsif usc.to_state == User::Status::ACTIVE && array_includes?(usc.connection_membership_to_roles, role.id) && !array_includes?(usc.connection_membership_from_roles, role.id)
        total_additions[usc.date_id - offset] += 1
        total_additions_except_user[usc.date_id - offset] += 1 if !total_additions_except_user.nil? && usc.user_id != ignore_user_id
      elsif usc.from_state == User::Status::ACTIVE && usc.to_state != User::Status::ACTIVE && array_includes?(usc.connection_membership_from_roles, role.id)
        total_removals[usc.date_id - offset] += 1
        total_removals_except_user[usc.date_id - offset] += 1 if !total_removals_except_user.nil? && usc.user_id != ignore_user_id
      elsif usc.from_state == User::Status::ACTIVE && !array_includes?(usc.connection_membership_to_roles, role.id) && array_includes?(usc.connection_membership_from_roles, role.id)
        total_removals[usc.date_id - offset] += 1
        total_removals_except_user[usc.date_id - offset] += 1 if !total_removals_except_user.nil? && usc.user_id != ignore_user_id
      end
    end

  end

end