require_relative './../../../../../../test_helper'

class EmployeeRolePopulatorTest < ActiveSupport::TestCase
  def test_add_roles
    program = programs(:primary_portal)
    employee_role = program.get_role(RoleConstants::EMPLOYEE_NAME)

    user_ids = (program.users - employee_role.users).collect(&:id).first(5)
    assert user_ids.size > 0, "No non employees found"

    employees_populator = EmployeeRolePopulator.new("employee_role", {parent: "user", percents_ary: [100], counts_ary: [1]})
    assert_difference 'employee_role.reload.users.count', user_ids.size do
      employees_populator.add_roles(user_ids, 5, {program: program})
    end
  end
end
