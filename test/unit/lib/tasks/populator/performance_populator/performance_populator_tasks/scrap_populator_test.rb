require_relative './../../../../../../test_helper'

class ScrapPopulatorTest < ActiveSupport::TestCase
  def test_add_scraps
    program = programs(:albers)
    to_add_group_ids = program.groups.pluck(:id).first(5)
    to_remove_group_ids = Scrap.where(ref_obj_type: Group.to_s).collect(&:ref_obj_id).uniq.last(5)
    populator_add_and_remove_objects("scrap", "group", to_add_group_ids, to_remove_group_ids, {program: program}) 
  end
end