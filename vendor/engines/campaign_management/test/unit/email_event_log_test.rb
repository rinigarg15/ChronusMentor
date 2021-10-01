require_relative './../test_helper'

class EmailEventLogTest < ActiveSupport::TestCase
  def test_type_should_be_valid_event_type
    event = cm_email_event_logs(:cm_email_event_opened_1)
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :event_type, "is not included in the list" do
      event.update_attributes!(event_type: 20)
    end
  end

  def test_every_event_should_have_a_valid_message_type
    event = CampaignManagement::EmailEventLog.new(:event_type => CampaignManagement::EmailEventLog::Type::OPENED, :timestamp => Time.now.strftime('%s').to_i, :message_id => messages(:first_campaigns_admin_message).id, :message_type => 'DummyMessageType')
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :message_type, "is not included in the list" do
      event.save!
    end
    event = CampaignManagement::EmailEventLog.new(:event_type => CampaignManagement::EmailEventLog::Type::DELIVERED, :timestamp => Time.now, :message_id => cm_campaign_emails(:first_program_invitation_campaign_messages_first_email).id, :message_type => CampaignManagement::EmailEventLog::MessageType::PROGRAM_INVITATION_MESSAGE)
    assert_nothing_raised do
      event.save!
    end
  end

  def test_every_event_should_have_a_message_id
    event = CampaignManagement::EmailEventLog.new(:event_type => CampaignManagement::EmailEventLog::Type::OPENED, :timestamp => Time.now.strftime('%s').to_i, :message_type => CampaignManagement::EmailEventLog::MessageType::ADMIN_MESSAGE)
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :message_id, "can't be blank" do
      event.save!
    end
  end

  def test_every_event_should_have_a_timestamp
    event = messages(:first_campaigns_admin_message).event_logs.new(:event_type => CampaignManagement::EmailEventLog::Type::OPENED)
    assert_raise_error_on_field ActiveRecord::RecordInvalid, "timestamp", "can't be blank" do
      event.save!
    end
  end

  def test_store_campaign_event_data_should_update_the_admin_message_event_log_if_legacy_event_is_received
    admin_message = messages(:first_campaigns_admin_message)
    params = {"event" => ChronusMentorMailgun::Event::SPAMMED,
      "recipient" => 'some_email@example.com', 
      "user-variables" => {"admin_message_id" => admin_message.id }, 
      "timestamp" => Time.now.strftime('%s').to_i
    }
    CampaignManagement::CampaignMessageAnalytics.expects(:add_to_campaign_message_analytics)
    assert_difference "admin_message.event_logs.count", 1  do
      CampaignManagement::EmailEventLog.store_campaign_event_data(params)
    end
  end

  def test_store_campaign_event_data_should_update_failed_event_only_if_it_permanent
    admin_message = messages(:first_campaigns_admin_message)
    params = {"event" => ChronusMentorMailgun::Event::FAILED,
      "recipient" => 'some_email@example.com',
      "user-variables" => {"admin_message_id" => admin_message.id }, 
      "timestamp" => Time.now.strftime('%s').to_i
    }
    CampaignManagement::CampaignMessageAnalytics.expects(:add_to_campaign_message_analytics).never
    assert_no_difference "admin_message.event_logs.count"  do
      CampaignManagement::EmailEventLog.store_campaign_event_data(params)
    end

    params['severity'] = 'permanent'
    CampaignManagement::CampaignMessageAnalytics.expects(:add_to_campaign_message_analytics)
    assert_difference "admin_message.event_logs.count", 1  do
      CampaignManagement::EmailEventLog.store_campaign_event_data(params)
    end

    params['severity'] = 'temporary'
    CampaignManagement::CampaignMessageAnalytics.expects(:add_to_campaign_message_analytics).never
    assert_no_difference "admin_message.event_logs.count"  do
      CampaignManagement::EmailEventLog.store_campaign_event_data(params)
    end
  end



  def test_store_campaign_event_should_update_admin_message_event_if_event_is_of_admin_message
    admin_message = messages(:first_campaigns_admin_message)
    params = {"event" => ChronusMentorMailgun::Event::SPAMMED, 
      "recipient" => 'some_email@example.com',
      "user-variables" => {
        'campaign' => {'message_id' => admin_message.id, 'message_type' => 'AbstractMessage'}
        },
      "timestamp" => Time.now.strftime('%s').to_i
      }
    
    CampaignManagement::CampaignMessageAnalytics.expects(:add_to_campaign_message_analytics)
    assert_difference "admin_message.event_logs.count", 1  do
      CampaignManagement::EmailEventLog.store_campaign_event_data(params)
    end
  end


  def test_store_campaign_event_should_update_campaign_email_if_event_is_of_campaign_email
    message = cm_campaign_emails(:first_program_invitation_campaign_messages_first_email)
    params = {"event" => ChronusMentorMailgun::Event::SPAMMED, 
      "recipient" => 'some_email@example.com',
      "user-variables" => {
        'campaign' => {'message_id' => message.id, 'message_type' => 'CampaignManagement::CampaignEmail'}
        },
      "timestamp" => Time.now.strftime('%s').to_i
      }
    
    CampaignManagement::CampaignMessageAnalytics.expects(:add_to_campaign_message_analytics)
    assert_difference "message.event_logs.count", 1  do
      CampaignManagement::EmailEventLog.store_campaign_event_data(params)
    end
  end


  def test_store_campaign_event_should_update_campaign_email_if_event_is_of_campaign_email_and_params_is_a_string
    message = cm_campaign_emails(:first_program_invitation_campaign_messages_first_email)
    campaign_params_hash = {'message_id' => message.id, 'message_type' => 'CampaignManagement::CampaignEmail'}
    params = {"event" => ChronusMentorMailgun::Event::SPAMMED, 
      "recipient" => 'some_email@example.com',
      "user-variables" => {
        'campaign' => JSON(campaign_params_hash)
        },
      "timestamp" => Time.now.strftime('%s').to_i
      }

    CampaignManagement::CampaignMessageAnalytics.expects(:add_to_campaign_message_analytics)
    assert_difference "message.event_logs.count", 1  do
      CampaignManagement::EmailEventLog.store_campaign_event_data(params)
    end
  end

  def test_store_campaign_event_data_only_if_message_is_present
    admin_message = messages(:first_campaigns_admin_message)
    params = {
      "event" => ChronusMentorMailgun::Event::OPENED,
      "recipient" => 'some_email@example.com',
      "user-variables" => {
        'campaign' => {'message_id' => admin_message.id, 'message_type' => 'AbstractMessage'}
      },
      "timestamp" => Time.now.strftime('%s').to_i
    }

    assert_difference "admin_message.event_logs.count", 1  do
      CampaignManagement::EmailEventLog.store_campaign_event_data(params)
    end

    admin_message.delete

    assert_no_difference "admin_message.event_logs.count"  do
      CampaignManagement::EmailEventLog.store_campaign_event_data(params.merge("timestamp" => (Time.now + 3.second).strftime('%s').to_i))
    end
  end


  def test_store_campaign_event_data_should_store_url_and_ensure_presence_of_open_event_incase_of_clicked_event
    message = cm_campaign_emails(:first_program_invitation_campaign_messages_second_email)
    time_now = Time.now.strftime('%s').to_i
    params = {"event" => ChronusMentorMailgun::Event::CLICKED,
      "recipient" => 'some_email@example.com',
      "url" => 'http://google.com',
      "timestamp" => time_now,
      "user-variables" => {
        "campaign" => {
          "message_type" => "CampaignManagement::CampaignEmail",
          "message_id" => message.id
        }
      }
    }

    CampaignManagement::CampaignMessageAnalytics.expects(:add_to_campaign_message_analytics).twice
    assert_false message.event_logs.where(event_type: CampaignManagement::EmailEventLog::Type::OPENED).present?
    assert_difference "CampaignManagement::EmailEventLog.count",2 do
      CampaignManagement::EmailEventLog.store_campaign_event_data(params)
    end
    assert message.event_logs.where(event_type: CampaignManagement::EmailEventLog::Type::OPENED).present?
    assert_difference "CampaignManagement::EmailEventLog.count",1 do
      CampaignManagement::EmailEventLog.store_campaign_event_data(params.merge("timestamp" => time_now + 1000))
    end

    email_event = CampaignManagement::EmailEventLog.last
    assert_equal "http://google.com", email_event.params
  end

  def test_no_duplicate_events_are_allowed_to_be_stored
    messages(:first_campaigns_admin_message).event_logs.create!(:event_type => CampaignManagement::EmailEventLog::Type::OPENED, "timestamp" => Time.new(2002))
    new_event = messages(:first_campaigns_admin_message).event_logs.new(:event_type => CampaignManagement::EmailEventLog::Type::OPENED, "timestamp" => Time.new(2002))
    assert_equal false, new_event.save
  end

  def test_any_similar_event_exists_already_should_return_status_as_expected
    event = messages(:first_campaigns_admin_message).event_logs.create!(:event_type => CampaignManagement::EmailEventLog::Type::SPAMMED, :timestamp => Time.new(2002))
    assert_false event.send(:any_similar_event_exists_already?)
    new_event = messages(:first_campaigns_admin_message).event_logs.create!(:event_type => CampaignManagement::EmailEventLog::Type::SPAMMED, :timestamp => Time.new(2002,02))
    assert new_event.send(:any_similar_event_exists_already?)
  end

  def test_get_campaign_email_id_and_type_should_return_admin_message_info_incase_of_legacy_events
    params =  {"admin_message_id" => 2}
    message_id, message_type, from_campaign = CampaignManagement::EmailEventLog.get_campaign_email_id_and_type(params)
    assert_equal 2, message_id
    assert_equal "AbstractMessage", message_type
    assert_false from_campaign

    params =  {'campaign' => {'message_id' => 10, 'message_type' => 'AbstractMessage'}}
    message_id, message_type, from_campaign = CampaignManagement::EmailEventLog.get_campaign_email_id_and_type(params)
    assert_equal 10, message_id
    assert_equal "AbstractMessage", message_type
    assert from_campaign
  end

  def test_update_analytics_summary_of_campaign_message_should_update_analytics_only_if_a_new_event_comes
    message = cm_campaign_emails(:first_program_invitation_campaign_messages_first_email)
    event_log = message.event_logs.create!(:event_type => CampaignManagement::EmailEventLog::Type::SPAMMED, "timestamp" => Time.new(2002))
    event_log.stubs(:message_older_than_campaign_enabled_at?).returns(false)
    CampaignManagement::CampaignMessageAnalytics.expects(:add_to_campaign_message_analytics)
    event_log.update_analytics_summary_of_campaign_message

    event_log = message.event_logs.create!(:event_type => CampaignManagement::EmailEventLog::Type::SPAMMED, "timestamp" => Time.new(2002,02))
    CampaignManagement::CampaignMessageAnalytics.expects(:add_to_campaign_message_analytics).never
    event_log.update_analytics_summary_of_campaign_message

    event_log.stubs(:message_older_than_campaign_enabled_at?).returns(true)
    event_log = message.event_logs.create!(:event_type => CampaignManagement::EmailEventLog::Type::OPENED, "timestamp" => Time.new(2002))
    CampaignManagement::CampaignMessageAnalytics.expects(:add_to_campaign_message_analytics).never
    event_log.update_analytics_summary_of_campaign_message
  end

  def test_message_older_than_campaign_enabled_at
    message = cm_campaign_emails(:first_program_invitation_campaign_messages_first_email)
    campaign = message.campaign_message.campaign
    campaign.update_attributes(enabled_at: Time.now)
    event_log = message.event_logs.create!(:event_type => CampaignManagement::EmailEventLog::Type::SPAMMED, "timestamp" => Time.new(2002))
    event_log.reload.send(:message_older_than_campaign_enabled_at?, message)
  end

  def test_store_campaign_event_data_of_message_from_migrated_org
    admin_message = messages(:first_campaigns_admin_message)
    admin_message.update_column(:source_audit_key, "staging_somedate_10")
    params = {
      "event" => ChronusMentorMailgun::Event::OPENED,
      "recipient" => 'some_email@example.com',
      "user-variables" => {
        'campaign' => {'message_id' => 10, 'message_type' => 'AbstractMessage'}
      },
      "timestamp" => Time.now.strftime('%s').to_i
    }

    assert_difference "admin_message.event_logs.count", 1  do
      CampaignManagement::EmailEventLog.store_campaign_event_data(params, "stagingmg.realizegoal.com")
    end
  end

  def test_store_campaign_event_data_of_message_from_migrated_org_of_same_env
    admin_message = messages(:first_campaigns_admin_message)
    admin_message.update_column(:source_audit_key, "test_somedate_99999")
    params = {
      "event" => ChronusMentorMailgun::Event::OPENED,
      "recipient" => 'some_email@example.com',
      "user-variables" => {
        'campaign' => {'message_id' => 99999, 'message_type' => 'AbstractMessage'}
      },
      "timestamp" => Time.now.strftime('%s').to_i
    }

    assert_difference "admin_message.event_logs.count", 1  do
      CampaignManagement::EmailEventLog.store_campaign_event_data(params)
    end
  end

  def test_should_not_store_campaign_event_data_of_message_without_campaign_message
    admin_message = messages(:first_campaigns_admin_message)
    admin_message.update_columns(campaign_message_id: nil)
    params = {
      "event" => ChronusMentorMailgun::Event::OPENED,
      "recipient" => 'some_email@example.com',
      "user-variables" => {
        'campaign' => {'message_id' => admin_message.id, 'message_type' => 'AbstractMessage'}
      },
      "timestamp" => Time.now.strftime('%s').to_i
    }

    assert_no_difference "admin_message.event_logs.count"  do
      CampaignManagement::EmailEventLog.store_campaign_event_data(params)
    end
  end

end


