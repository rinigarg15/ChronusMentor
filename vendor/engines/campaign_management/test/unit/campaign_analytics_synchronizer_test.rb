require_relative './../test_helper'
require 'mailgun'

class CampaignAnalyticsSynchronizerTest < ActiveSupport::TestCase

  def setup
    super
    @@mg_client_mock ||= mock
    @@mg_events_mock ||= mock
    Mailgun::Client.stubs(:new).returns(@@mg_client_mock)
    Mailgun::Events.stubs(:new).returns(@@mg_events_mock)
  end

  def test_sync
    events_array_mock = mock
    events_array_mock2 = mock
    events_array = [
          {
            "user-variables" => {},
            "event" => "dropped",
            "timestamp" => "1407314177.8627763"
          },
          {
            "user-variables" => {"admin_message_id" => messages(:first_campaigns_admin_message).id},
            "event" => "opened",
            "timestamp" => "1407314177.9047763"
          },
          {
            "user-variables" => {"admin_message_id" => messages(:first_campaigns_admin_message).id},
            "event" => "clicked",
            "timestamp" => 1407314177.9997763
          }
      ]
    events_array_mock.expects(:to_h).returns("items" => events_array)
    events_array_mock2.expects(:to_h).returns("items" => [])

    @@mg_events_mock.expects(:get).returns(events_array_mock)
    @@mg_events_mock.expects(:next).returns(events_array_mock2)

    CampaignManagement::CampaignAnalyticsSynchronizer.instance.sync
  end


  def test_get_start_time
    cas = CampaignManagement::CampaignAnalyticsSynchronizer.instance
    assert_equal Time.new(2005,01,2).to_f, cas.send(:get_start_time)
  end

  # After a mailgun api fails, the start time should be the one, updated from the last call
  def test_sync_fail_case
    events_array_mock = mock
    events_array = [
          {
            "user-variables" => {"admin_message_id" => messages(:first_campaigns_admin_message).id},
            "event" => "opened",
            "timestamp" => "1407314177.9047763"
          }
      ]
    events_array_mock.expects(:to_h).returns("items" => events_array)
    @@mg_events_mock.expects(:get).returns(events_array_mock)
    # If any of the mailgun 
    @@mg_events_mock.expects(:next).raises(StandardError)

    assert_raise(StandardError) do
      CampaignManagement::CampaignAnalyticsSynchronizer.instance.sync
    end
    assert_equal 1407314177.0, CampaignManagement::CampaignAnalyticsSynchronizer.instance.send(:get_start_time)
  end

  def test_sync_should_raise_exception_in_fail_case
    events_array_mock = mock
    events_array_mock2 = mock
    events_array = [
          {
            "user-variables" => {"admin_message_id" => messages(:first_campaigns_admin_message).id},
            "event" => "opened",
            "timestamp" => "1407314177.9047763"
          }
      ]
    events_array_mock.expects(:to_h).returns("items" => events_array)
    events_array_mock2.expects(:to_h).returns("items" => [])
    @@mg_events_mock.expects(:get).returns(events_array_mock)
    @@mg_events_mock.expects(:next).returns(events_array_mock2)

    CampaignManagement::EmailEventLog.expects(:store_campaign_event_data).raises(StandardError)
    
    CampaignManagement::CampaignAnalyticsSynchronizer.instance.sync
    assert_equal 1104604200, CampaignManagement::CampaignAnalyticsSynchronizer.instance.send(:get_start_time)
  end

  def test_has_campaign_info_should_respond_as_expected
    item = {"user-variables" => {} }
    assert_false CampaignManagement::CampaignAnalyticsSynchronizer.instance.send(:has_campaign_info?, item)

    item = {"user-variables" => {"admin_message_id" => messages(:first_campaigns_admin_message).id} }
    assert CampaignManagement::CampaignAnalyticsSynchronizer.instance.send(:has_campaign_info?, item)

    item = {"user-variables" => {"campaign" => {"message_type" => "AbstractMessage", "message_id" => messages(:first_campaigns_admin_message).id} } }
    assert CampaignManagement::CampaignAnalyticsSynchronizer.instance.send(:has_campaign_info?, item)
  end

  def test_get_mailgun_domains_to_parse
    sync_instance = CampaignManagement::CampaignAnalyticsSynchronizer.instance
    programs(:org_primary).update_column(:source_audit_key, "staging_somedate_100")
    mailgun_domains = sync_instance.send(:get_mailgun_domains_to_parse)
    assert_equal ["testmg.realizegoal.com", "stagingmg.realizegoal.com"], mailgun_domains
  end

end
