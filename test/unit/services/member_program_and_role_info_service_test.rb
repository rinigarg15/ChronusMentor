require_relative './../../test_helper.rb'

class MemberProgramAndRoleInfoServiceTest < ActiveSupport::TestCase
  def test_fetch_member_roles_hash
    member = members(:f_admin)
    program = programs(:albers)
    user = users(:f_admin)
    member_role_info_service = MemberProgramAndRoleInfoService.new(programs(:org_primary))
    member_roles_hash1 = member_role_info_service.fetch_member_roles_hash([member.id])
    assert_equal 1, member_roles_hash1.size
    assert_equal members(:f_admin).programs.count, member_roles_hash1[member.id].size
    assert_equal program.name, member_roles_hash1[member.id].first[:program_name]
    assert_equal user.roles.collect{|role| RoleConstants.human_role_string([role.name], program: program)}, member_roles_hash1[member.id].first[:role_names]
    assert_equal program.root, member_roles_hash1[member.id].first[:program_root]
    assert_equal user.suspended?, member_roles_hash1[member.id].first[:user_suspended]

    member_roles_hash2 = member_role_info_service.fetch_member_roles_hash(programs(:org_primary).members.pluck(:id))
    assert_equal programs(:org_primary).members.count, member_roles_hash2.size
  end
end