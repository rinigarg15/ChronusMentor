require_relative './../test_helper'

class CampaignManagement::AbstractCampaignStateTest < ActiveSupport::TestCase
  def test_activate
    campaign = cm_campaigns(:active_campaign_1)
    campaign.update_attribute(:state, CampaignManagement::AbstractCampaign::STATE::DRAFTED)
    campaign.activate!
    assert_equal CampaignManagement::AbstractCampaign::STATE::ACTIVE, campaign.state
  end

  def test_cleanup_items_when_not_active
    campaign = cm_campaigns(:active_campaign_1)
    campaign.stubs(:cleanup_campaign_jobs).once
    campaign.stubs(:cleanup_campaign_statuses).once
    campaign.cleanup_items_when_not_active
  end

  def test_stop
    campaign = cm_campaigns(:active_campaign_1)
    campaign.stubs(:cleanup_items_when_not_active).once
    campaign.stop!
    assert_equal CampaignManagement::AbstractCampaign::STATE::STOPPED, campaign.state
  end

  def test_set_enabled_at
    campaign = cm_campaigns(:active_campaign_1)
    campaign.enabled_at = nil
    campaign.save!
    assert campaign.reload.enabled_at.present?

    campaign.enabled_at = nil
    campaign.update_attribute(:state, CampaignManagement::AbstractCampaign::STATE::DRAFTED)
    campaign.save!
    assert_nil campaign.reload.enabled_at
  end
end