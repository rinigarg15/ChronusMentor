require_relative './../../../../../../test_helper'

class ProgramEventPopulatorTest < ActiveSupport::TestCase
  def test_add_program_events
    org = programs(:org_primary)
    to_add_program_ids = org.programs.pluck(:id).first(5)
    to_remove_program_ids = ProgramEvent.pluck(:program_id).uniq.last(5)
    populator_add_and_remove_objects("program_event", "program", to_add_program_ids, to_remove_program_ids, { organization: org, additional_populator_class_options: {common: {"translation_locales" => ["fr-CA", "en"]}}})
  end
end