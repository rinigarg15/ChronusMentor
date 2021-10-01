require_relative './../../../../../../test_helper'

class FlagPopulatorTest < ActiveSupport::TestCase
  def test_add_remove_flags
    org = programs(:org_primary)
    to_add_program_ids = org.programs.pluck(:id).first(5)
    to_remove_program_ids = Flag.pluck(:program_id).uniq.last(5)
    populator_add_and_remove_objects("flag", "program", to_add_program_ids, to_remove_program_ids, {organization: org})
  end
end