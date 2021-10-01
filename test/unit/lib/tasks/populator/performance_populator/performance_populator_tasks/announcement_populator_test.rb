require_relative './../../../../../../test_helper'

class AnnouncementPopulatorTest < ActiveSupport::TestCase
  def test_add_remove_announcements
    org = programs(:org_primary)
    to_add_program_ids = org.programs.pluck(:id).first(5)
    to_remove_program_ids = Announcement.pluck(:program_id).last(5).uniq
    populator_add_and_remove_objects("announcement", "program", to_add_program_ids, to_remove_program_ids, {organization: org, additional_populator_class_options: {common: {"translation_locales" => ["fr-CA", "en"]}}})
  end

  def test_add_remove_announcements_for_portal
    org = programs(:org_nch)
    to_add_program_ids = org.programs.pluck(:id).first(5)
    to_remove_program_ids = Announcement.pluck(:program_id).last(5).uniq
    populator_add_and_remove_objects("announcement", "program", to_add_program_ids, to_remove_program_ids, {organization: org, additional_populator_class_options: {common: {"translation_locales" => ["fr-CA", "en"]}}})
  end
end