require_relative './../../../../../../test_helper'

class ResourcePoulatorTest < ActiveSupport::TestCase
  def test_add_resources
    org = programs(:org_primary)
    to_add_program_ids = org.programs.pluck(:id).first(5)
    to_remove_program_ids = Resource.pluck(:program_id).uniq.last(5)
    populator_add_and_remove_objects("resource", "program", to_add_program_ids, to_remove_program_ids, {organization: org, additional_populator_class_options: {common: {"translation_locales" => ["fr-CA", "en"]}}}) 
  end

  def test_add_resources_for_portal
    org = programs(:org_nch)
    to_add_program_ids = org.programs.pluck(:id).first(5)
    to_remove_program_ids = Resource.pluck(:program_id).uniq.last(5)
    populator_add_and_remove_objects("resource", "program", to_add_program_ids, to_remove_program_ids, {organization: org, additional_populator_class_options: {common: {"translation_locales" => ["fr-CA", "en"]}}})
  end
end