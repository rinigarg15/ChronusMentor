require_relative './../../../../../../test_helper'

class PendingUserPoulatorTest < ActiveSupport::TestCase
  def test_add_pending_users
    program = programs(:albers)
    org = programs(:org_primary)
    pending_user_populator = PendingUserPopulator.new("pending_user", {parent: "member", percents_ary: [50, 25, 25], counts_ary: [3, 2, 1]})
    count = 1
    member_ids = org.members.pluck(:id).last(5)
    assert_difference "program.users.where(:state => User::Status::PENDING).count", member_ids.size * count do
     pending_user_populator.add_pending_users(member_ids, count, {organization: org, program: program})
    end
    role = program.roles.find_by(name: "RoleConstants::MENTOR_NAME".constantize)
    RolePopulator.add_roles(program.users.last(member_ids.size * count).collect(&:id), member_ids.size * count, {program: program}, role)
    populator_object_save!(program.users.last)
  end

  def test_remove_pending_users
    program = programs(:albers)
    org = program.organization
    pending_user_populator = PendingUserPopulator.new("pending_user", {parent: "member", percents_ary: [50, 25, 25], counts_ary: [3, 2, 1]})
    count = 1
    member_ids = program.users.where(:state => User::Status::PENDING).pluck(:member_id).uniq.last(5)
    assert_difference "program.users.where(:state => User::Status::PENDING).count", -(member_ids.size * count) do
     pending_user_populator.remove_pending_users(member_ids, count, {organization: org, program: program})
    end
  end
end