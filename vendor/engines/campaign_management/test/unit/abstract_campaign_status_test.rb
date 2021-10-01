require_relative './../test_helper'

class AbstractCampaignStatusTest < ActiveSupport::TestCase
  def test_presence_of_type_in_abstract_campaign_status
    abstract_campaign_status = CampaignManagement::UserCampaignStatus.new
    abstract_campaign_status.type = nil
    abstract_campaign_status.save
    assert_equal_unordered ["can't be blank", "is not included in the list"], abstract_campaign_status.errors[:type]
  end

  def test_presence_of_type_in_the_list
    abstract_campaign_status = cm_campaign_statuses(:admin_active_campaign_status)
    abstract_campaign_status.type = "invalid abstract_campaign_status type"
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :type, "is not included in the list" do
      abstract_campaign_status.save!
    end
  end

end
