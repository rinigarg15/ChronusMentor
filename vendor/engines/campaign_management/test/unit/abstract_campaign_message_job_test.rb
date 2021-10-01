require_relative './../test_helper'

class AbstractCampaignMessageJobTest < ActiveSupport::TestCase
  def test_presence_of_type_in_abstract_campaign_status
    abstract_campaign_message_job = CampaignManagement::UserCampaignMessageJob.new
    abstract_campaign_message_job.type = nil
    abstract_campaign_message_job.save
    assert_equal_unordered ["can't be blank", "is not included in the list"], abstract_campaign_message_job.errors[:type]
  end

  def test_presence_of_type_in_the_list
    abstract_campaign_message_job = cm_campaign_message_jobs(:pending_active_campaign_message_1_job_for_admin)
    abstract_campaign_message_job.type = "invalid abstract_campaign_message_job type"
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :type, "is not included in the list" do
      abstract_campaign_message_job.save!
    end
  end

  def test_uniqueness_validations
    abstract_campaign_message_job = cm_campaign_message_jobs(:pending_active_campaign_message_1_job_for_admin)
    new_job = CampaignManagement::UserCampaignMessageJob.new(campaign_message_id: abstract_campaign_message_job.campaign_message_id, abstract_object_id: abstract_campaign_message_job.abstract_object_id, abstract_object_type: abstract_campaign_message_job.abstract_object_type)
    assert_false new_job.valid?
    assert_equal ["has already been taken"], new_job.errors[:campaign_message_id]
  end

end
