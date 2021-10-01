require_relative './../test_helper'

class UserCampaignMessageTest < ActiveSupport::TestCase

  def test_belongs_to_campaign
    assert_equal cm_campaigns(:active_campaign_1), cm_campaign_messages(:campaign_message_1).campaign
  end

  def test_is_duration_editable_returns_true
    campaign_message = cm_campaign_messages(:campaign_message_1)
    assert campaign_message.is_duration_editable?
  end 

  def test_user_campaign_message_can_have_many_emails
    campaign_message = cm_campaign_messages(:campaign_message_1)
    assert_equal 3, campaign_message.emails.count
  end

  def test_deleteing_campaign_message_should_not_delete_the_corresponding_admin_message
    a = AdminMessage.new(:program => programs(:albers), :sender_name => 'Test ', :sender_email => "test@example.com", :subject => 'Test', :content => 'This is the content', :campaign_message_id => cm_campaign_messages(:campaign_message_1).id)
    a.message_receivers = [AdminMessages::Receiver.new(:message => a)]
    a.save!
    assert_equal 4, cm_campaign_messages(:campaign_message_1).emails.size
    assert_no_difference "AdminMessage.count" do
      cm_campaigns(:active_campaign_1).destroy
    end
  end

  def test_create_jobs_for_eligible_statuses
    time_now = Time.now
    campaign = cm_campaigns(:active_campaign_1)
    campaign_message = campaign.campaign_messages[0]
    campaign_message.update_column(:duration, 10)
    assert_equal 2, campaign.statuses.size
    status_1 = campaign.statuses[0]
    status_2 = campaign.statuses[1]
    campaign_jobs = campaign_message.jobs
    campaign_emails = campaign_message.emails
    campaign_jobs.destroy_all
    campaign_emails.delete_all

    assert_equal 2, campaign.statuses.where("started_at >= ?", time_now - campaign_message.duration.days).size
    assert_difference "campaign_jobs.reload.size", 2 do
      campaign_message.create_jobs_for_eligible_statuses(time_now)
    end

    assert_no_difference "campaign_jobs.reload.size" do
      campaign_message.create_jobs_for_eligible_statuses(time_now)
    end

    campaign_jobs.reload.destroy_all
    create_admin_message(receivers: [status_1.user.member], campaign_message_id: campaign_message.id, sender_id: members(:f_admin).id)
    assert_difference "campaign_jobs.reload.size", 1 do
      campaign_message.create_jobs_for_eligible_statuses(time_now)
    end

    campaign_emails.reload.delete_all
    campaign_jobs.reload.destroy_all
    status_1.update_column(:started_at, Time.now - 20.days)
    status_2.update_column(:started_at, Time.now - 20.days)
    assert_no_difference "campaign_jobs.reload.size" do
      campaign_message.create_jobs_for_eligible_statuses(time_now)
    end
  end

  def test_stop_campaign_if_no_campaign_messages
    campaign = cm_campaigns(:cm_campaigns_1)
    campaign.update_attribute(:state, CampaignManagement::AbstractCampaign::STATE::DRAFTED)
    campaign.expects(:stop!).never
    campaign.campaign_messages.destroy_all

    campaign = cm_campaigns(:active_campaign_2)
    campaign.expects(:stop!).never
    campaign.campaign_messages.first.destroy

    campaign.expects(:stop!).once
    campaign.campaign_messages.destroy_all

    campaign = cm_campaigns(:active_campaign_1)
    campaign.expects(:stop!).never
    campaign.destroy
  end

  def test_mark_campaign_active_if_needed
    campaign = cm_campaigns(:active_campaign_1)
    campaign.update_attribute(:state, CampaignManagement::AbstractCampaign::STATE::DRAFTED)

    cm = campaign.campaign_messages.new(duration: 1, sender_id: users(:f_admin).id)
    cm.build_email_template(program_id: programs(:albers).id, source: "Something", subject: "Nothing")
    cm.email_template.belongs_to_cm = true
    cm.save!
    assert_false campaign.reload.active?

    cm = campaign.campaign_messages.new(duration: 1, sender_id: users(:f_admin).id)
    cm.build_email_template(program_id: programs(:albers).id, source: "Something1", subject: "Nothing1")
    cm.email_template.belongs_to_cm = true
    cm.mark_campaign_active = true
    cm.save!
    assert campaign.reload.active?
  end
end