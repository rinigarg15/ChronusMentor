require_relative './../test_helper.rb'

class ObjectRolePermissionTest < ActiveSupport::TestCase
  def test_validations
    orp = ObjectRolePermission.new
    assert_false orp.save
    orp.ref_obj = programs(:albers)
    assert_false orp.save
    orp.role = programs(:albers).roles.first
    assert_false orp.save
    orp.object_permission = ObjectPermission.first
    assert orp.save
  end

  def test_uniqueness_validation
    program = programs(:albers)
    role = program.roles.first
    permission = ObjectPermission.first
    assert_not_nil ObjectRolePermission.create(ref_obj: program, role: role, object_permission: permission).id
    assert_nil ObjectRolePermission.create(ref_obj: program, role: role, object_permission: permission).id
    assert_not_nil ObjectRolePermission.create(ref_obj: program, role: role, object_permission: ObjectPermission.last).id
  end

  def test_object_permission_name
    assert_equal "manage_mm_goals", object_role_permissions(:object_role_permissions_1).object_permission_name
  end

  def test_role_name
    assert_equal "admin", object_role_permissions(:object_role_permissions_1).role_name
  end
end
