require_relative './../test_helper'

class CampaignMessageAnalyticsTest < ActiveSupport::TestCase

  # Though there are no fixtures for this model, they are created in the observer of email event log. Write tests accordingly
  def test_duplicate_entries_are_NOT_allowed_to_be_stored
    campaign_analytics_entry = CampaignManagement::CampaignMessageAnalytics.first
    event = CampaignManagement::CampaignMessageAnalytics.new(:campaign_message_id => campaign_analytics_entry.campaign_message_id, :year_month => campaign_analytics_entry.year_month, :event_type => campaign_analytics_entry.event_type, :event_count => 4)

    assert_raise_error_on_field ActiveRecord::RecordInvalid, :campaign_message_id, 'has already been taken' do
      event.save!
    end

  end

  def test_event_type_should_be_VALID_as_in_CampaignManagement_EmailEventLog
    campaign_analytics_entry = CampaignManagement::CampaignMessageAnalytics.first
    event = CampaignManagement::CampaignMessageAnalytics.new(:campaign_message_id => campaign_analytics_entry.campaign_message_id, :year_month => campaign_analytics_entry.year_month, :event_type => 10, :event_count => 4)

    assert_raise_error_on_field ActiveRecord::RecordInvalid, :event_type do
      event.save!
    end
  end

  def test_add_to_campaign_message_analytics_should_update_existing_count_for_events_with_prior_summary_record
    event_summaries = CampaignManagement::CampaignMessageAnalytics.where(:campaign_message_id => cm_campaign_messages(:campaign_message_1).id, :year_month => "200401", :event_type => CampaignManagement::EmailEventLog::Type::OPENED)
    assert_equal 1, event_summaries.first.event_count

    CampaignManagement::CampaignMessageAnalytics.add_to_campaign_message_analytics(cm_campaign_messages(:campaign_message_1), "200401", CampaignManagement::EmailEventLog::Type::OPENED)

    event_summaries = CampaignManagement::CampaignMessageAnalytics.where(:campaign_message_id => cm_campaign_messages(:campaign_message_1).id, :year_month => "200401", :event_type => CampaignManagement::EmailEventLog::Type::OPENED)
    assert_equal 2, event_summaries.first.event_count
  end


  def test_add_to_campaign_message_analytics_should_create_new_record_for_events_with_no_prior_summary_record
    event_summaries = CampaignManagement::CampaignMessageAnalytics.where(:campaign_message_id => cm_campaign_messages(:campaign_message_1).id, :year_month => "201401", :event_type => CampaignManagement::EmailEventLog::Type::OPENED)

    assert event_summaries.empty?

    CampaignManagement::CampaignMessageAnalytics.add_to_campaign_message_analytics(cm_campaign_messages(:campaign_message_1), "201401", CampaignManagement::EmailEventLog::Type::OPENED)

    event_summaries = CampaignManagement::CampaignMessageAnalytics.where(:campaign_message_id => cm_campaign_messages(:campaign_message_1).id, :year_month => "201401", :event_type => CampaignManagement::EmailEventLog::Type::OPENED)

    assert_equal 1, event_summaries.count
    assert_equal 1, event_summaries.first.event_count
  end



end
