require_relative './../../../test_helper'

class UserHomePageWidgetTest < ActiveSupport::TestCase
  # Testing methods on user class directly

  def test_can_render_home_page_widget
    user = users(:f_mentor_pbe)
    assert user.program.project_based?

    user.stubs(:available_projects_for_user).returns([[], false])
    assert_false user.can_render_home_page_widget?

    user.stubs(:available_projects_for_user).returns([[2], "something"])
    assert user.can_render_home_page_widget?

    user2 = users(:f_admin)
    assert_false user2.program.project_based?
    user2.stubs(:available_projects_for_user).returns([[3], "something"])
    assert_false user2.can_render_home_page_widget?
  end

  def test_roles_for_sending_project_request
    user = users(:f_mentor_pbe)
    program = programs(:pbe)
    mentor_role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    mentor_role.remove_permission("send_project_request")

    assert_equal [RoleConstants::MENTOR_NAME], user.roles.for_mentoring.pluck(:name)
    assert_false mentor_role.has_permission_name?("send_project_request")

    assert_equal [], user.roles_for_sending_project_request
    mentor_role.add_permission("send_project_request")
    mentor_role.reload
    assert_equal [mentor_role], user.reload.roles_for_sending_project_request
    mentor_role.update_column(:max_connections_limit, 0)
    assert_empty user.reload.roles_for_sending_project_request
  end

  def test_available_projects_for_user_for_scope
    user = users(:f_mentor_pbe)
    program = programs(:pbe)
    active_group = groups(:group_pbe)
    active_group.update_members([users(:pbe_mentor_0)], active_group.students)
    assert_false user.groups.include?(active_group)
    assert user.roles.administrative.empty?
    user.stubs(:roles_for_sending_project_request).returns(user.roles.administrative)
    assert_equal [[], false], user.available_projects_for_user_for_scope
    assert_equal [[], false], user.available_projects_for_user_for_scope(program.groups)

    user.stubs(:roles_for_sending_project_request).returns(program.roles.for_mentoring)
    assert_equal [[groups(:group_pbe_0), groups(:group_pbe_1), groups(:group_pbe_2), groups(:group_pbe_3), groups(:group_pbe_4), active_group], true], user.reload.available_projects_for_user_for_scope
    assert_equal [[active_group], false], user.available_projects_for_user_for_scope(program.groups.active)

    groups(:group_pbe_0).update_attribute(:global, false)
    assert_equal [[groups(:group_pbe_1), groups(:group_pbe_2), groups(:group_pbe_3), groups(:group_pbe_4), active_group], false], user.reload.available_projects_for_user_for_scope
    assert_equal [[groups(:group_pbe_0), groups(:group_pbe_1), groups(:group_pbe_2), groups(:group_pbe_3), groups(:group_pbe_4), active_group], true], user.available_projects_for_user_for_scope(program.groups.open_connections)

    ids = user.send(:ids_of_groups_user_is_part_of_or_sent_request_to)
    user.stubs(:ids_of_groups_user_is_part_of_or_sent_request_to).returns((ids + [groups(:group_pbe_1).id]))
    assert_equal [[groups(:group_pbe_2), groups(:group_pbe_3), groups(:group_pbe_4), active_group], false], user.available_projects_for_user_for_scope
  end

  def test_available_projects_for_user
    user1 = users(:f_mentor_pbe)
    user1.stubs(:available_projects_for_user_for_scope).returns(["something", "something"])
    assert_equal ["something", "something"], user1.available_projects_for_user

    user2 = users(:f_mentor)
    user2.stubs(:available_projects_for_user_for_scope).returns(["something else", "something"])
    assert_equal [], user2.available_projects_for_user 
  end

  def test_ids_of_groups_user_is_part_of_or_sent_request_to
    user = users(:f_mentor)
    group_ids = user.groups.pluck(:id)
    assert_equal [], user.sent_project_requests

    assert_equal group_ids, user.send(:ids_of_groups_user_is_part_of_or_sent_request_to)

    user.stubs(:sent_project_requests).returns(ProjectRequest.active)
    assert_equal_unordered (group_ids + ProjectRequest.active.pluck(:group_id)).uniq, user.send(:ids_of_groups_user_is_part_of_or_sent_request_to)

    user.stubs(:groups).returns(Group.active)
    assert_equal_unordered (ProjectRequest.active.pluck(:group_id) + Group.active.pluck(:id)).uniq, user.send(:ids_of_groups_user_is_part_of_or_sent_request_to)
  end

end