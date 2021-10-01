require_relative './../test_helper'

class SurveyCampaignMessageTest < ActiveSupport::TestCase

  def setup
    super
    @program = programs(:albers)
    @campaign = CampaignManagement::SurveyCampaign.first
    @campaign_messages = @campaign.campaign_messages
    @campaign_message_1 = @campaign_messages[0]
    @campaign_message_2 = @campaign_messages[1]
  end

  def test_belongs_to_campaign
    assert_equal @campaign, @campaign_message_1.campaign
  end

  def test_have_many_jobs
    survey = surveys(:two)
    campaign = survey.campaign
    campaign_message = campaign.campaign_messages.first
    create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id, required: true, due_date: Date.today - 2.days)
    assert_equal 0, campaign_message.jobs.count

    campaign.process!
    assert_equal 1, campaign_message.reload.jobs.count
  end

  def test_have_many_emails
    survey = surveys(:two)
    campaign = survey.campaign
    campaign_message = campaign.campaign_messages.first
    task = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id, required: true, due_date: Date.today - 10.days)
    assert_equal 0, campaign_message.emails.count

    campaign_email = CampaignManagement::CampaignEmail.create!(:subject => "subject", :source => "Source", :campaign_message => campaign_message, :abstract_object_id => task.id)
    assert_equal [campaign_email.id], campaign_message.emails.pluck(:id)
  end

  def test_validate_campaign_presence
    scm = CampaignManagement::SurveyCampaignMessage.new
    scm.save
    assert_equal ["can't be blank"], scm.errors[:campaign]
  end

  def test_validate_duration
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :duration, "is not a number" do
      @campaign_message_1.update_attributes!(duration: nil)
    end

    assert_raise_error_on_field ActiveRecord::RecordInvalid, :duration, "is not a number" do
      @campaign_message_1.update_attributes!(duration: "Test")
    end

    assert_raise_error_on_field ActiveRecord::RecordInvalid, :duration, "must be greater than or equal to 0" do
      @campaign_message_1.update_attributes!(duration: "-1")
    end
  end

  def test_is_duration_editable
    assert @campaign_message_1.is_duration_editable?
  end

  def test_is_last_message
    assert_false @campaign_message_1.is_last_message?
  end

  def test_handle_existing_jobs
    survey = surveys(:two)
    campaign = survey.campaign
    campaign_message = campaign.campaign_messages.first
    task = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id, required: true, due_date: Date.today - 2.days)
    assert_equal 0, campaign_message.jobs.count

    campaign.process!
    job = campaign_message.reload.jobs.first
    assert_equal (task.due_date + campaign_message.duration.days).to_i, job.run_at.to_i

    campaign_message.update_attribute(:duration, 3)
    campaign_message.reload
    assert_no_difference "CampaignManagement::SurveyCampaignMessageJob.count" do
      campaign_message.handle_existing_jobs
    end
    assert_equal 1, campaign_message.jobs.count
    assert_equal (task.due_date + campaign_message.duration.days).to_i, job.reload.run_at.to_i

    campaign_message.update_attribute(:duration, 0)
    campaign_message.reload.handle_existing_jobs
    assert_equal 0, campaign_message.jobs.count
  end

  def test_create_jobs_for_eligible_statuses
    survey = surveys(:two)
    campaign = survey.campaign
    campaign.campaign_messages.first.destroy
    campaign.reload
    task1 = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id, required: true, due_date: Date.today - 6.days)
    task2 = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id, required: true, due_date: Date.today - 15.days)
    task3 = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id, required: true, due_date: Date.today - 15.days)
    task4 = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id, required: true, due_date: Date.today - 60.days)

    assert_difference "CampaignManagement::SurveyCampaignStatus.count", 4 do
      assert_difference "CampaignManagement::SurveyCampaignMessageJob.count", 1 do
        campaign.process!
      end
    end

    cm = campaign.campaign_messages.first
    assert_equal cm.id, CampaignManagement::SurveyCampaignMessageJob.last.campaign_message_id
    assert_equal task1.id, CampaignManagement::SurveyCampaignMessageJob.last.abstract_object_id
    assert_equal 1, cm.jobs.count

    email = CampaignManagement::CampaignEmail.create!(:subject => "subject", :source => "Source", :campaign_message => cm, :abstract_object_id => task2.id)

    cm.update_attribute(:duration, 50)
    cm.create_jobs_for_eligible_statuses(Time.now)
    assert_equal 2, cm.jobs.count
    assert_equal task3.id, CampaignManagement::SurveyCampaignMessageJob.last.abstract_object_id
  end
end