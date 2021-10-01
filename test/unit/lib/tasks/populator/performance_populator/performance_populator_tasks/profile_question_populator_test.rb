require_relative './../../../../../../test_helper'

class ProfileQuestionPopulatorTest < ActiveSupport::TestCase
  def test_add_profile_questions
    to_add_organization_ids = Organization.pluck(:id).first(5)
    to_remove_organization_ids = ProfileQuestion.pluck(:organization_id).uniq.first(5)
    populator_add_and_remove_objects("profile_question", "organization", to_add_organization_ids, to_remove_organization_ids, {additional_populator_class_options: {common: {"translation_locales" => ["fr-CA", "en"]}}})
  end
end