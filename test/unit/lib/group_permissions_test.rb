require_relative './../../test_helper.rb'

class GroupPermissionsTest < ActiveSupport::TestCase
  def test_can_manage_or_own_group
    program = programs(:albers)
    group = create_group(name: "Claire Underwood", students: [], mentors: [], program: program, status: Group::Status::PENDING)
    group.update_members([users(:f_mentor)], [users(:f_student)])
    group.membership_of(users(:f_student)).update_attributes!(owner: true)
    
    assert users(:f_student).can_manage_or_own_group?(group)
    assert users(:f_admin).can_manage_or_own_group?(group)
    assert_false users(:f_mentor).can_manage_or_own_group?(group)    
  end

  def test_project_manager_or_owner
    assert users(:f_admin_pbe).project_manager_or_owner?
    assert_false users(:f_mentor_pbe).project_manager_or_owner?

    program = programs(:pbe)
    group = create_group(name: "Claire Underwood", students: [], mentors: [], program: program, status: Group::Status::PENDING)
    group.update_members([users(:f_mentor_pbe)], [users(:f_student_pbe)])
    group.membership_of(users(:f_mentor_pbe)).update_attributes!(owner: true)

    assert users(:f_mentor_pbe).project_manager_or_owner?
  end

  def test_can_approve_project_requests
    program = programs(:pbe)
    group = create_group(name: "Claire Underwood", students: [], mentors: [], program: program, status: Group::Status::PENDING)
    assert users(:f_admin_pbe).can_approve_project_requests?(group)
    assert_false users(:f_mentor_pbe).can_approve_project_requests?(group)

    group.update_members([users(:f_mentor_pbe)], [users(:f_student_pbe)])
    group.membership_of(users(:f_student_pbe)).update_attributes!(owner: true)
    
    assert users(:f_student_pbe).can_approve_project_requests?(group.reload)
  end

  def test_has_owned_groups
    program = programs(:pbe)
    assert_false users(:f_admin_pbe).has_owned_groups?
    assert_false users(:f_mentor_pbe).has_owned_groups?
    
    group = create_group(name: "Claire Underwood", students: [], mentors: [], program: program, status: Group::Status::PENDING)
    group.update_members([users(:f_mentor_pbe)], [users(:f_student_pbe)])
    group.membership_of(users(:f_student_pbe)).update_attributes!(owner: true)
    
    assert users(:f_student_pbe).has_owned_groups?
  end

  def test_is_owner_of
    proposer = users(:f_mentor_pbe)
    program = programs(:pbe)
    group = create_group(name: "Claire Underwood - Francis Underwood", students: [], mentors: [users(:f_mentor_pbe)], program: program, status: Group::Status::PROPOSED, creator_id: users(:f_mentor_pbe).id)
    assert_false proposer.is_owner_of?(group)
    group.make_proposer_owner!
    assert proposer.is_owner_of?(group.reload)
  end

  def test_can_manage_members_of_group
    program = programs(:pbe)
    
    group = create_group(name: "Claire Underwood", students: [], mentors: [], program: program, status: Group::Status::PENDING)
    group.update_members([users(:f_mentor_pbe)], [users(:f_student_pbe)])
    group.membership_of(users(:f_student_pbe)).update_attributes!(owner: true)

    assert users(:f_student_pbe).can_manage_members_of_group?(group.reload)
    assert users(:f_admin_pbe).can_manage_members_of_group?(group)
    assert_false users(:f_mentor_pbe).can_manage_members_of_group?(group)

    program.roles.for_mentoring.each do |role|
      role.update_attributes(can_be_added_by_owners: false)
    end

    assert_false users(:f_student_pbe).can_manage_members_of_group?(group)
    assert users(:f_admin_pbe).can_manage_members_of_group?(group)
    assert_false users(:f_mentor_pbe).can_manage_members_of_group?(group)

    program.roles.for_mentoring.first.update_attributes(can_be_added_by_owners: true)
    assert users(:f_student_pbe).can_manage_members_of_group?(group)
    assert_false users(:f_mentor_pbe).can_manage_members_of_group?(group)
  end


  def test_can_manage_role_in_group
    program = programs(:pbe)
    
    group = create_group(name: "Claire Underwood", students: [], mentors: [], program: program, status: Group::Status::PENDING)
    group.update_members([users(:f_mentor_pbe)], [users(:f_student_pbe)])
    group.membership_of(users(:f_student_pbe)).update_attributes!(owner: true)

    role = program.roles.for_mentoring.first
    role.update_attributes(can_be_added_by_owners: true)

    assert users(:f_student_pbe).can_manage_role_in_group?(group.reload, role)
    assert users(:f_admin_pbe).can_manage_role_in_group?(group, role)
    assert_false users(:f_mentor_pbe).can_manage_role_in_group?(group, role)

    role.update_attributes(can_be_added_by_owners: false)

    assert_false users(:f_student_pbe).can_manage_role_in_group?(group, role)
    assert users(:f_admin_pbe).can_manage_role_in_group?(group, role)
    assert_false users(:f_mentor_pbe).can_manage_role_in_group?(group, role)
  end

  def test_can_be_shown_project_request_quick_link
    user = users(:f_admin_pbe)
    assert_false user.can_be_shown_project_request_quick_link?
    user = users(:f_student_pbe)
    assert user.can_be_shown_project_request_quick_link?
    user.roles.each{ |r| r.remove_permission("send_project_request") }
    assert_false user.can_be_shown_project_request_quick_link?

    group = create_group(name: "Claire Underwood", students: [], mentors: [], program: programs(:pbe), status: Group::Status::PENDING)
    group.update_members([users(:f_mentor_pbe)], [users(:f_student_pbe)])
    group.membership_of(users(:f_student_pbe)).update_attributes!(owner: true)
    assert user.can_be_shown_project_request_quick_link?
  end
end