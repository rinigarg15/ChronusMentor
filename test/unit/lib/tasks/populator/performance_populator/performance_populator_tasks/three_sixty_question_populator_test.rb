require_relative './../../../../../../test_helper'

class ThreeSixtyQuestionPopulatorTest < ActiveSupport::TestCase
  def test_add_three_sixty_questions
    to_add_organization_ids = Organization.pluck(:id).first(5)
    to_remove_organization_ids = ThreeSixty::Question.pluck(:organization_id).uniq.first(5)
    populator_add_and_remove_objects("three_sixty_question", "organization", to_add_organization_ids, to_remove_organization_ids, {model: "three_sixty/question", additional_populator_class_options: {common: {"translation_locales" => ["fr-CA", "en"]}}})
  end
end