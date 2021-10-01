require_relative './../test_helper'

class UserCampaignStatusTest < ActiveSupport::TestCase
  def test_belongs
    user = users(:f_admin)
    campaign = cm_campaigns(:active_campaign_1)
    status = CampaignManagement::UserCampaignStatus.create!(user: user, campaign: campaign)

    assert_equal user, status.user
    assert_equal campaign, status.campaign
  end

  def test_user_validation
    status = CampaignManagement::UserCampaignStatus.new(user: nil, campaign: cm_campaigns(:active_campaign_1))

    assert_false status.valid?
    assert status.errors.has_key?(:user)
  end

  def test_campaign_message_validation
    status = CampaignManagement::UserCampaignStatus.new(user: users(:f_admin), campaign: nil)

    assert_false status.valid?
    assert status.errors.has_key?(:campaign)
  end

  def test_set_abstract_object_type
    status = CampaignManagement::UserCampaignStatus.create
    assert_equal User.name, status.abstract_object_type
  end

end
