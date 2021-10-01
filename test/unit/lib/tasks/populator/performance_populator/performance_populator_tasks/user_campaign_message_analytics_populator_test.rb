require_relative './../../../../../../test_helper'

class UserCampaignMessageAnalyticsPopulatorTest < ActiveSupport::TestCase
  def test_add_user_campaign_message_analytics
   program = programs(:albers)
    user_campaign_ids = program.user_campaigns.pluck(:id).first(5)
    to_add_user_campaign_message_ids = CampaignManagement::UserCampaignMessage.where(campaign_id: user_campaign_ids).pluck(:id)
    to_remove_user_campaign_message_ids = CampaignManagement::CampaignMessageAnalytics.pluck(:campaign_message_id).uniq.last(5)
    populator_add_and_remove_objects("user_campaign_message_analytics", "user_campaign_message", to_add_user_campaign_message_ids, to_remove_user_campaign_message_ids, {program: program, model: "campaign_management/campaign_message_analytics"})
  end
end