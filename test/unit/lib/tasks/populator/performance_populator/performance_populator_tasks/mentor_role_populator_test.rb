require_relative './../../../../../../test_helper'

class MentorRolePopulatorTest < ActiveSupport::TestCase
  def test_add_roles
    program = programs(:albers)
    user_ids = program.users.students.pluck(:id).first(5)
    mentor_role_populator = MentorRolePopulator.new("mentor_role", {parent: "user", percents_ary: [66], counts_ary: [1]})
    assert_difference "program.users.mentors.count", 5 do
      mentor_role_populator.add_roles(user_ids, 5, {program: program})
    end
  end
end