require_relative './../test_helper'

class AbstractCampaignTest < ActiveSupport::TestCase

  def test_has_many_campaign_messages
    assert_equal 4, cm_campaigns(:active_campaign_1).campaign_messages.size
    assert_difference "CampaignManagement::AbstractCampaignMessage.count", -4 do
      cm_campaigns(:active_campaign_1).destroy
    end
  end

  def test_presence_of_type_in_campaign
    campaign = CampaignManagement::AbstractCampaign.new
    campaign.type = nil
    campaign.save
    assert_equal ["can't be blank", "is not included in the list"], campaign.errors[:type]
  end

  def test_presence_of_type_in_the_list
    campaign = cm_campaigns(:active_campaign_1)
    campaign.type = "invalid campaign type"
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :type, "is not included in the list" do
      campaign.save!
    end
  end

  def test_presence_of_title
    campaign = CampaignManagement::AbstractCampaign.new(:state => CampaignManagement::AbstractCampaign::STATE::STOPPED)
    campaign.save
    assert_equal ["can't be blank"], campaign.errors[:title]
    campaign = CampaignManagement::AbstractCampaign.new(:state => CampaignManagement::AbstractCampaign::STATE::ACTIVE)
    campaign.save
    assert_equal ["can't be blank"], campaign.errors[:title]
  end

  def test_cleanup_jobs
    campaign = cm_campaigns(:active_campaign_1)

    campaign_message = campaign.campaign_messages.first

    campaign.cleanup_jobs_for_object_ids([1, 2])
    assert_equal 0, campaign.jobs.count
  end

  def test_create_campaign_message_jobs_function
    campaign = cm_campaigns(:active_campaign_1)
    assert_equal 2, campaign.statuses.count
    time = Time.zone.now
    campaign.send(:create_campaign_message_jobs, [users(:f_user).id], time)
    assert_equal 3, campaign.statuses.count
    assert time=campaign.statuses.last.started_at
    assert_equal 12, campaign.jobs.count
  end

  def test_destroy_should_cleanup_jobs
    campaign = cm_campaigns(:active_campaign_1)
    campaign_id = campaign.id
    campaign_message_ids = campaign.campaign_messages.pluck(:id)

    assert_equal 2, campaign.statuses.count
    assert_equal 8, campaign.jobs.count

    campaign.destroy

    assert_equal 0, CampaignManagement::UserCampaignStatus.where(:campaign_id => campaign_id).count
    assert_equal 0, CampaignManagement::UserCampaignMessageJob.where(:campaign_message_id => campaign_message_ids).count
  end

  def test_calculate_overall_analytics
    campaign = cm_campaigns(:active_campaign_1)
    total_aggregates_expected = { 0 => 3, 1 => 2, 3 => 1, 4 => 2 }

    total_aggregates = campaign.calculate_overall_analytics
    assert_equal total_aggregates_expected, total_aggregates
  end

   # {"200401"=>{0=>1, 1=>1 3=>1, 4=>1}} for campaign_message id 1
   # {"200401"=>{1=>1}} for campaign_message id 2
   # {"200312"=>{4=>1}} for campaign_message id 3
  def test_calculate_monthly_aggregate_analytics
    campaign = cm_campaigns(:active_campaign_1)
    analytics_summary_keys = ["200401", "200312"]
    monthly_aggregates_expected = {"200401"=>{0=>2, 1=>2, 3=>1, 4=>1}, "200312"=>{4=>1}}

    monthly_aggregates = campaign.calculate_monthly_aggregated_analytics(analytics_summary_keys)
    assert_equal monthly_aggregates_expected, monthly_aggregates
  end

  def test_get_supported_tags_and_widgets_should_return_values_as_expected
    campaign  = cm_campaigns(:active_campaign_1)
    tags, widgets = campaign.get_supported_tags_and_widgets

    assert_equal 16, tags.count
    assert_equal [], widgets


    campaign  = programs(:albers).program_invitation_campaign
    tags, widgets = campaign.get_supported_tags_and_widgets

    assert_equal 8, tags.count
    assert_equal [], widgets
  end

  def test_get_analytics_keys_should_return_start_end_times_and_analytics_info
    campaign = cm_campaigns(:active_campaign_1)
    campaign.update_attribute(:enabled_at, campaign.created_at) #setting enable at to created_at wthi is 6 months ago
    starting_time, ending_time, analytics_info = campaign.send('get_analytics_keys', {})

    expected_start_time  = ending_time - 5.months
    assert (expected_start_time > campaign.created_at)
    assert_equal expected_start_time, starting_time
    assert_time_is_equal_with_delta Time.now.to_i, ending_time.to_i
    assert_equal 6, analytics_info.count
  end

  def test_get_analytics_stats_should_calculate_sent_delivered_opened_and_clicked_counts
    campaign = cm_campaigns(:active_campaign_1)
    campaign.update_attribute(:enabled_at, campaign.created_at) #setting enable at to created_at which is 6 months ago
    analytic_stats = campaign.send('get_analytics_stats', {})

    #calculating analytics for this campaign for last 6 months. but all the events were happened before 6 months.
    assert (analytic_stats[:starting_time] > campaign.enabled_at)
    start_time = Time.at(analytic_stats[:starting_time]).strftime("%Y%m")
    #last event happened before starting_time of this analytics period
    assert (start_time > campaign.campaign_message_analyticss.last.year_month)

    assert_equal [0, 0, 0, 0, 0, 0], analytic_stats[:sent]
    assert_equal [0, 0, 0, 0, 0, 0], analytic_stats[:clicked]
    assert_equal [0, 0, 0, 0, 0, 0], analytic_stats[:opened]
    assert_equal [0, 0, 0, 0, 0, 0], analytic_stats[:delivered]
  end

  def test_get_analytics_details_should_calculate_overall
    campaign = cm_campaigns(:active_campaign_1)
    overall_analytics, analytic_stats = campaign.get_analytics_details
    assert_equal 5, analytic_stats[:total_sent_count]
    assert_equal 40.0, analytic_stats[:click_rate]
    assert_equal 60.0, analytic_stats[:open_rate]

    total_analytics = {0=>3, 4=>2, 3=>1, 1=>2}
    assert_equal total_analytics, overall_analytics
  end

  def test_translated_fields
    campaign = cm_campaigns(:active_campaign_1)
    Globalize.with_locale(:en) do
      campaign.title = "english title"
      campaign.save!
    end
    Globalize.with_locale(:"fr-CA") do
      campaign.title = "french title"
      campaign.save!
    end
    Globalize.with_locale(:en) do
      assert_equal "english title", campaign.title
    end
    Globalize.with_locale(:"fr-CA") do
      assert_equal "french title", campaign.title
    end
  end
end