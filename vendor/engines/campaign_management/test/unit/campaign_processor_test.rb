require_relative './../test_helper'

class CampaignProcessorTest < ActiveSupport::TestCase

  def test_start_method
    CampaignManagement::UserCampaign.any_instance.stubs(:process!)
    CampaignManagement::UserCampaign.any_instance.expects(:process!).at_least(1)
    assert CampaignManagement::SurveyCampaign.count > 0
    CampaignManagement::SurveyCampaign.any_instance.stubs(:process!).times(CampaignManagement::SurveyCampaign.count)
    CampaignManagement::CampaignProcessor.instance.start
  end

  def test_check_admin_view_deletion_availability
    admin_view = programs(:org_primary).admin_views.find_by(default_view: AbstractView::DefaultType::LICENSE_COUNT)
    assert_empty CampaignManagement::CampaignProcessor.instance.campaign_using_admin_view(admin_view)

    admin_view = programs(:albers).admin_views.find_by(default_view: AbstractView::DefaultType::ALL_USERS)
    assert_equal 6, CampaignManagement::CampaignProcessor.instance.campaign_using_admin_view(admin_view).size
  end
end