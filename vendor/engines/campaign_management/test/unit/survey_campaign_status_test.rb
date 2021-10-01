require_relative './../test_helper'

class SurveyCampaignStatusTest < ActiveSupport::TestCase
  def test_belongs
    survey = surveys(:two)
    task = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id, required: true, due_date: Date.today - 9.days)
    campaign = survey.campaign
    status = CampaignManagement::SurveyCampaignStatus.create!(abstract_object: task, campaign: campaign)

    assert_equal task, status.abstract_object
    assert_equal campaign, status.campaign
  end

  def test_task_validation
    survey = surveys(:two)
    campaign = survey.campaign
    status = CampaignManagement::SurveyCampaignStatus.new(abstract_object: nil, campaign: campaign)

    assert_false status.valid?
    assert status.errors.has_key?(:abstract_object_id)
    assert_false status.errors.has_key?(:abstract_object_type)
  end

  def test_campaign_message_validation
    task = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: surveys(:two).id, required: true, due_date: Date.today - 9.days)
    status = CampaignManagement::SurveyCampaignStatus.new(abstract_object: task, campaign: nil)

    assert_false status.valid?
    assert status.errors.has_key?(:campaign)
  end

  def test_set_abstract_object_type
    survey = surveys(:two)
    campaign = survey.campaign
    status = CampaignManagement::SurveyCampaignStatus.create(campaign: campaign)
    assert_equal MentoringModel::Task.name, status.abstract_object_type

    campaign.stubs(:abstract_object_klass).returns(MemberMeeting)
    status = CampaignManagement::SurveyCampaignStatus.create(campaign: campaign)
    assert_equal MemberMeeting.name, status.abstract_object_type
  end

end
