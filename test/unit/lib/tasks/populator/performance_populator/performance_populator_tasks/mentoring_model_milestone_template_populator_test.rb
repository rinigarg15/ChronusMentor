require_relative './../../../../../../test_helper'

class MentoringModelMilestoneTemplatePopulatorTest < ActiveSupport::TestCase
  def test_add_mentoring_model_milestone_template
    org = programs(:org_primary)
    to_add_mentoring_model_ids = MentoringModel.pluck(:id).last(5) 
    to_remove_mentoring_model_ids = MentoringModel.pluck(:id).last(5)
    populator_add_and_remove_objects("mentoring_model_milestone_template", "mentoring_model", to_add_mentoring_model_ids, to_remove_mentoring_model_ids, {organization: org, model: "mentoring_model/milestone_template", additional_populator_class_options: {common: {"translation_locales" => ["fr-CA", "en"]}}})
  end
end