require_relative './../../../test_helper.rb'

class DummyConnectionFiltersController < ApplicationController
  include ConnectionFilters
  common_extensions

  def index
    head :ok
  end

  def some_action
    head :ok
  end
end

class ConnectionFilters::CommonExtensionsTest < ActionController::TestCase
  tests DummyConnectionFiltersController

  def test_index
    @controller.expects(:fetch_group).once
    @controller.expects(:fetch_current_connection_membership).once
    @controller.expects(:check_member_or_admin).once.returns(true)
    @controller.expects(:check_action_access).never
    @controller.expects(:check_group_active).never
    @controller.expects(:prepare_template).once
    @controller.expects(:can_access_mentoring_area?).once.returns(true)
    @controller.expects(:update_login_count).once
    @controller.expects(:update_last_visited_tab).once

    current_user_is :f_admin
    get :index
  end

  def test_index_permission_denied_neither_member_nor_admin
    @controller.expects(:fetch_group).once
    @controller.expects(:fetch_current_connection_membership).once
    @controller.expects(:check_member_or_admin).once.returns(false)
    @controller.expects(:check_action_access).never
    @controller.expects(:check_group_active).never
    @controller.expects(:prepare_template).never
    @controller.expects(:can_access_mentoring_area?).never
    @controller.expects(:update_login_count).never
    @controller.expects(:update_last_visited_tab).never

    current_user_is :f_admin
    assert_permission_denied do
      get :index
    end
  end

  def test_index_permission_denied_cannot_access_mentoring_area
    @controller.expects(:fetch_group).once
    @controller.expects(:fetch_current_connection_membership).once
    @controller.expects(:check_member_or_admin).once.returns(true)
    @controller.expects(:check_action_access).never
    @controller.expects(:check_group_active).never
    @controller.expects(:prepare_template).once
    @controller.expects(:can_access_mentoring_area?).once.returns(false)
    @controller.expects(:update_login_count).never
    @controller.expects(:update_last_visited_tab).never

    current_user_is :f_admin
    assert_permission_denied do
      get :index
    end
  end

  def test_some_action
    @controller.expects(:fetch_group).once
    @controller.expects(:fetch_current_connection_membership).once
    @controller.expects(:check_member_or_admin).never
    @controller.expects(:check_action_access).once.returns(true)
    @controller.expects(:check_group_active).once.returns(true)
    @controller.expects(:prepare_template).never
    @controller.expects(:can_access_mentoring_area?).never
    @controller.expects(:update_login_count).never
    @controller.expects(:update_last_visited_tab).never

    current_user_is :f_admin
    get :some_action
  end

  def test_some_action_permission_denied_cannot_access
    @controller.expects(:fetch_group).once
    @controller.expects(:fetch_current_connection_membership).once
    @controller.expects(:check_member_or_admin).never
    @controller.expects(:check_action_access).once.returns(false)
    @controller.expects(:check_group_active).never
    @controller.expects(:prepare_template).never
    @controller.expects(:can_access_mentoring_area?).never
    @controller.expects(:update_login_count).never
    @controller.expects(:update_last_visited_tab).never

    current_user_is :f_admin
    assert_permission_denied do
      get :some_action
    end
  end

  def test_some_action_permission_denied_inactive_group
    @controller.expects(:fetch_group).once
    @controller.expects(:fetch_current_connection_membership).once
    @controller.expects(:check_member_or_admin).never
    @controller.expects(:check_action_access).once.returns(true)
    @controller.expects(:check_group_active).once.returns(false)
    @controller.expects(:prepare_template).never
    @controller.expects(:can_access_mentoring_area?).never
    @controller.expects(:update_login_count).never
    @controller.expects(:update_last_visited_tab).never

    current_user_is :f_admin
    assert_permission_denied do
      get :some_action
    end
  end
end