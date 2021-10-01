require_relative './../../../test_helper.rb'

class UserSearchTest < ActiveSupport::TestCase

  def test_users_sort_param_string
    obj = Object.new
    obj.extend(UserSearch)
    assert_equal(["match", "ASC"], obj.users_sort_order_string("match", "ASC", programs(:albers)))
    assert_equal(["match", "DESC"], obj.users_sort_order_string("match", "DESC", programs(:albers)))

    assert_equal(Program::SortUsersBy::FULL_NAME, programs(:albers).sort_users_by)
    assert_equal(["name_only.sort", "DESC"], obj.users_sort_order_string("name", "DESC", programs(:albers)))
    assert_equal(["name_only.sort", "ASC"], obj.users_sort_order_string("name", "ASC", programs(:albers)))

    p = programs(:albers); p.sort_users_by = Program::SortUsersBy::LAST_NAME; p.save!
    assert_equal(Program::SortUsersBy::LAST_NAME, programs(:albers).reload.sort_users_by)
    assert_equal([["last_name.sort", "first_name.sort"], "DESC"], obj.users_sort_order_string("name", "DESC", programs(:albers)))
    assert_equal([["last_name.sort", "first_name.sort"], "ASC"], obj.users_sort_order_string("name", "ASC", programs(:albers)))
  end

  def test_get_state_filter_options
    obj = Object.new
    obj.extend(UserSearch)
    assert_equal User::Status::ACTIVE, obj.send(:get_state_filter_options)
    obj.instance_variable_set(:@is_matches_for_student, true)
    assert_equal [User::Status::ACTIVE, User::Status::PENDING], obj.send(:get_state_filter_options)
    obj.instance_variable_set(:@is_matches_for_student, false)
    obj.instance_variable_set(:@state, User::Status::SUSPENDED)
    obj.instance_variable_set(:@current_user, users(:f_admin))
    User.any_instance.stubs(:can_manage_user_states?).returns(true)
    assert_equal User::Status::SUSPENDED, obj.send(:get_state_filter_options)
    obj.instance_variable_set(:@state, nil)
    assert_equal [User::Status::ACTIVE, User::Status::PENDING], obj.send(:get_state_filter_options)
  end

  def test_sort_and_paginate_users
    obj = Object.new
    obj.extend(UserSearch)
    user = users(:f_admin)
    user.stubs(:student_cache_normalized).returns({1 => 50, 2 => 0, 3 => 70, 4 => 0, 5 => 100})
    obj.instance_variable_set(:@current_program, programs(:albers))
    obj.instance_variable_set(:@current_user, user)
    obj.instance_variable_set(:@pagination_options, {page: 1, per_page: 10})
    obj.instance_variable_set(:@match_view, true)
    obj.instance_variable_set(:@student_document_available, true)
    obj.instance_variable_set(:@user_ids, [1,2,3,4,5,6])
    obj.instance_variable_set(:@is_sort_by_match, true)
    obj.instance_variable_set(:@hide_no_match_users, true)
    obj.stubs(:sort_users_by_match_score).once
    obj.send(:sort_and_paginate_users, user)

    obj.instance_variable_set(:@is_sort_by_match, false)
    obj.instance_variable_set(:@is_sort_by_preference, true)
    obj.stubs(:sort_users_by_match_score).never
    obj.stubs(:move_not_a_match_mentors_to_last).never
    obj.send(:sort_and_paginate_users, user)

    obj.instance_variable_set(:@hide_no_match_users, false)
    obj.stubs(:sort_users_by_match_score).never
    obj.stubs(:move_not_a_match_mentors_to_last).once
    obj.send(:sort_and_paginate_users, user)
  end

  def test_move_not_a_match_mentors_to_last
    obj = Object.new
    obj.extend(UserSearch)
    obj.instance_variable_set(:@match_results, {1 => 50, 2 => 0, 3 => 70, 4 => 0, 6 => 100})
    obj.instance_variable_set(:@user_ids, [1,2,3,4,5,6])
    obj.send(:move_not_a_match_mentors_to_last)
    assert_equal [1,3,6,2,4,5], obj.instance_variable_get(:@user_ids)
  end
end