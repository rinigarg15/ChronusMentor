require_relative './../../../test_helper.rb'

class DummyForumExtensionsController < ApplicationController
  include ForumExtensions
  group_forum_extensions([:index], [])

  def show
    head :ok
  end

  def index
    head :ok
  end
end

class ForumExtensions::CommonExtensionsTest < ActionController::TestCase
  tests DummyForumExtensionsController

  def test_show_group_forum
    @controller.stubs(:check_group_forum).returns(true)
    @controller.stubs(:associated_group_pending?).returns(false)
    @controller.stubs(:associated_group_active?).returns(true)
    @controller.expects(:add_group_id_to_params).once
    @controller.expects(:fetch_group).once
    @controller.expects(:fetch_current_connection_membership).once
    @controller.expects(:check_member_or_admin).once.returns(true)
    @controller.expects(:check_group_open).never
    @controller.expects(:check_action_access).never
    @controller.expects(:can_access_mentoring_area?).once.returns(true)
    @controller.expects(:set_src).never
    @controller.expects(:set_from_find_new).never
    @controller.expects(:set_group_profile_view).never
    @controller.expects(:prepare_template).once
    @controller.expects(:update_login_count).once
    @controller.expects(:update_last_visited_tab).once

    current_user_is users(:f_mentor)
    get :show
  end

  def test_show_pending_group_forum
    @controller.stubs(:check_group_forum).returns(true)
    @controller.stubs(:associated_group_pending?).returns(true)
    @controller.stubs(:associated_group_active?).returns(false)
    @controller.expects(:add_group_id_to_params).once
    @controller.expects(:fetch_group).once
    @controller.expects(:fetch_current_connection_membership).once
    @controller.expects(:check_member_or_admin).once.returns(true)
    @controller.expects(:check_group_open).never
    @controller.expects(:check_action_access).never
    @controller.expects(:can_access_mentoring_area?).never
    @controller.expects(:set_src).once
    @controller.expects(:set_from_find_new).once
    @controller.expects(:set_group_profile_view).once
    @controller.expects(:prepare_template).once
    @controller.expects(:update_login_count).never
    @controller.expects(:update_last_visited_tab).never

    current_user_is users(:f_mentor)
    get :show
  end

  def test_show_group_forum_neither_member_nor_admin
    @controller.stubs(:check_group_forum).returns(true)
    @controller.stubs(:associated_group_pending?).returns(false)
    @controller.stubs(:associated_group_active?).returns(true)
    @controller.expects(:add_group_id_to_params).once
    @controller.expects(:fetch_group).once
    @controller.expects(:fetch_current_connection_membership).once
    @controller.expects(:check_member_or_admin).once.returns(false)
    @controller.expects(:check_group_open).never
    @controller.expects(:check_action_access).never
    @controller.expects(:can_access_mentoring_area?).never
    @controller.expects(:prepare_template).never
    @controller.expects(:update_login_count).never
    @controller.expects(:update_last_visited_tab).never

    current_user_is users(:f_mentor)
    assert_permission_denied do
      get :show
    end
  end

  def test_show_group_forum_cannot_access_mentoring_area
    @controller.stubs(:check_group_forum).returns(true)
    @controller.stubs(:associated_group_pending?).returns(false)
    @controller.stubs(:associated_group_active?).returns(true)
    @controller.expects(:add_group_id_to_params).once
    @controller.expects(:fetch_group).once
    @controller.expects(:fetch_current_connection_membership).once
    @controller.expects(:check_member_or_admin).once.returns(true)
    @controller.expects(:check_group_open).never
    @controller.expects(:check_action_access).never
    @controller.expects(:can_access_mentoring_area?).once.returns(false)
    @controller.expects(:prepare_template).never
    @controller.expects(:update_login_count).never
    @controller.expects(:update_last_visited_tab).never

    current_user_is users(:f_mentor)
    assert_permission_denied do
      get :show
    end
  end

  def test_show_program_forum
    @controller.stubs(:check_group_forum).returns(false)
    @controller.expects(:add_group_id_to_params).never
    @controller.expects(:fetch_group).never
    @controller.expects(:fetch_current_connection_membership).never
    @controller.expects(:check_member_or_admin).never
    @controller.expects(:check_group_open).never
    @controller.expects(:check_action_access).never
    @controller.expects(:can_access_mentoring_area?).never
    @controller.expects(:prepare_template).never
    @controller.expects(:update_login_count).never
    @controller.expects(:update_last_visited_tab).never

    current_user_is users(:f_mentor)
    get :show
  end

  def test_index_group_forum
    @controller.stubs(:check_group_forum).returns(true)
    @controller.stubs(:associated_group_pending?).returns(false)
    @controller.stubs(:associated_group_active?).returns(true)
    @controller.expects(:add_group_id_to_params).once
    @controller.expects(:fetch_group).once
    @controller.expects(:fetch_current_connection_membership).once
    @controller.expects(:check_member_or_admin).never
    @controller.expects(:check_group_open).once.returns(true)
    @controller.expects(:check_action_access).once.returns(true)
    @controller.expects(:can_access_mentoring_area?).never
    @controller.expects(:prepare_template).never
    @controller.expects(:update_login_count).never
    @controller.expects(:update_last_visited_tab).never

    current_user_is users(:f_mentor)
    get :index
  end

  def test_index_group_forum_cannot_access
    @controller.stubs(:check_group_forum).returns(true)
    @controller.stubs(:associated_group_pending?).returns(false)
    @controller.stubs(:associated_group_active?).returns(true)
    @controller.expects(:add_group_id_to_params).once
    @controller.expects(:fetch_group).once
    @controller.expects(:fetch_current_connection_membership).once
    @controller.expects(:check_member_or_admin).never
    @controller.expects(:check_group_open).once.returns(true)
    @controller.expects(:check_action_access).once.returns(false)
    @controller.expects(:can_access_mentoring_area?).never
    @controller.expects(:prepare_template).never
    @controller.expects(:update_login_count).never
    @controller.expects(:update_last_visited_tab).never

    current_user_is users(:f_mentor)
    assert_permission_denied do
      get :index
    end
  end

  def test_index_group_forum_non_open
    @controller.stubs(:check_group_forum).returns(true)
    @controller.stubs(:associated_group_pending?).returns(false)
    @controller.stubs(:associated_group_active?).returns(false)
    @controller.expects(:add_group_id_to_params).once
    @controller.expects(:fetch_group).once
    @controller.expects(:fetch_current_connection_membership).once
    @controller.expects(:check_member_or_admin).never
    @controller.expects(:check_group_open).once.returns(false)
    @controller.expects(:check_action_access).never
    @controller.expects(:can_access_mentoring_area?).never
    @controller.expects(:prepare_template).never
    @controller.expects(:update_login_count).never
    @controller.expects(:update_last_visited_tab).never

    current_user_is users(:f_mentor)
    assert_permission_denied do
      get :index
    end
  end

  def test_index_program_forum
    @controller.stubs(:check_group_forum).returns(false)
    @controller.expects(:add_group_id_to_params).never
    @controller.expects(:fetch_group).never
    @controller.expects(:fetch_current_connection_membership).never
    @controller.expects(:check_member_or_admin).never
    @controller.expects(:check_action_access).never
    @controller.expects(:check_group_open).never
    @controller.expects(:can_access_mentoring_area?).never
    @controller.expects(:prepare_template).never
    @controller.expects(:update_login_count).never
    @controller.expects(:update_last_visited_tab).never

    current_user_is users(:f_mentor)
    get :index
  end
end