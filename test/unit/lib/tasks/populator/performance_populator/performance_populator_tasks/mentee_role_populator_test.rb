require_relative './../../../../../../test_helper'

class MenteeRolePopulatorTest < ActiveSupport::TestCase
  def test_add_roles
    program = programs(:albers)
    user_ids = program.users.mentors.pluck(:id).first(5)
    mentees_populator = MenteeRolePopulator.new("mentee_role", {parent: "user", percents_ary: [66], counts_ary: [1]})
    assert_difference "program.users.students.count", 5 do
      mentees_populator.add_roles(user_ids, 5, {program: program})
    end
  end
end