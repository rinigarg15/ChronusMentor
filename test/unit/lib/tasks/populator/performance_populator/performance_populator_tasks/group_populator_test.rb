require_relative './../../../../../../test_helper'

class GroupPopulatorTest < ActiveSupport::TestCase
  def test_add_remove_groups
    group_populator = GroupPopulator.new("group", {parent: "program", percents_ary: [50, 25, 25], counts_ary: [3, 2, 1]})
    program = programs(:albers)
    count = 5
    assert_difference "program.groups.count", count do
      group_populator.add_groups(program, count)
    end
    populator_object_save!(program.groups.last)
    assert_difference "program.groups.count", -(count) do
      group_populator.remove_groups(program, count)
    end
  end
end