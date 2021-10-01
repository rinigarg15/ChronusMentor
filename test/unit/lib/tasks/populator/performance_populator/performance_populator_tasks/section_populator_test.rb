require_relative './../../../../../../test_helper'

class SectionPopulatorTest < ActiveSupport::TestCase
  def test_add_sections
    to_add_organization_ids = Organization.pluck(:id).first(5)
    to_remove_organization_ids = Section.pluck(:program_id).uniq.first(5)
    populator_add_and_remove_objects("section", "organization", to_add_organization_ids, to_remove_organization_ids, {additional_populator_class_options: {common: {"translation_locales" => ["fr-CA", "en"]}}})
  end
end