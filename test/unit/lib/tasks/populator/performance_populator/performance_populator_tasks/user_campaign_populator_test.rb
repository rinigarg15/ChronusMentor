require_relative './../../../../../../test_helper'

class UserCampaignPopulatorTest < ActiveSupport::TestCase
  def test_add_user_campaigns
    org = programs(:org_primary)
    to_add_program_ids = org.programs.pluck(:id).first(5)
    to_remove_program_ids = CampaignManagement::UserCampaign.pluck(:program_id).uniq.last(5)
    populator_add_and_remove_objects("user_campaign", "program", to_add_program_ids, to_remove_program_ids, organization: org, model: "campaign_management/user_campaign", additional_populator_class_options: { common: { "translation_locales" => ["fr-CA", "en"] } } )
  end
end