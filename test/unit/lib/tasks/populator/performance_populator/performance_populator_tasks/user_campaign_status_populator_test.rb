require_relative './../../../../../../test_helper'

class UserCampaignStatusPopulatorTest < ActiveSupport::TestCase
  def test_add_user_campaign_status
    program = programs(:albers)
    to_add_user_campaign_ids = program.user_campaigns.pluck(:id).first(5)
    to_remove_user_campaign_ids = CampaignManagement::UserCampaignStatus.pluck(:campaign_id).uniq.last(5)
    populator_add_and_remove_objects("user_campaign_status", "user_campaign", to_add_user_campaign_ids, to_remove_user_campaign_ids, {program: program, model: "campaign_management/user_campaign_status"})
  end
end