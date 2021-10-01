require_relative './../../../../../../test_helper'

class UserPopulatorTest < ActiveSupport::TestCase
  def test_add_users
    program = programs(:albers)
    org = programs(:org_primary)
    user_populator = UserPopulator.new("user", {parent: "member", percents_ary: [50, 25, 25], counts_ary: [3, 2, 1]})
    count = 1
    member_ids = org.members.pluck(:id).last(5)
    assert_difference "program.users.active.count", member_ids.size * count do
     user_populator.add_users(member_ids, count, {organization: org, program: program})
    end
    role = program.roles.find_by(name: "RoleConstants::MENTOR_NAME".constantize)
    RolePopulator.add_roles(program.users.last(member_ids.size * count).collect(&:id), member_ids.size * count, {program: program}, role)
    populator_object_save!(program.users.last)
  end

  def test_remove_users
    program = programs(:albers)
    org = program.organization
    user_populator = UserPopulator.new("user", {parent: "member", percents_ary: [50, 25, 25], counts_ary: [3, 2, 1]})
    count = 1
    member_ids = program.users.active.pluck(:member_id).uniq.last(5)
    assert_difference "program.users.active.count", -(member_ids.size * count) do
     user_populator.remove_users(member_ids, count, {organization: org, program: program})
    end
  end
end