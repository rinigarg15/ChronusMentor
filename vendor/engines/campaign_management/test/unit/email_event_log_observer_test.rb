require_relative './../test_helper'

class EmailEventLogObserverTest < ActiveSupport::TestCase

  def test_email_event_log_creation_should_call_analytics_update
    CampaignManagement::EmailEventLog.any_instance.expects(:update_analytics_summary_of_campaign_message).returns
    messages(:second_campaigns_admin_message).event_logs.create!(
        :event_type => CampaignManagement::EmailEventLog::Type::OPENED,
        :timestamp => Time.at(Time.now.strftime('%s').to_i)
    )
  end

  def test_email_clicked_event_log_creation_should_call_handle_clicked_event
    campaign_email = messages(:second_campaigns_admin_message)
    CampaignManagement::EmailEventLog.any_instance.expects(:handle_clicked_event).once
    campaign_email.event_logs.create!(
        :event_type => CampaignManagement::EmailEventLog::Type::CLICKED,
        :timestamp => Time.at(Time.now.strftime('%s').to_i)
    )

    CampaignManagement::EmailEventLog.any_instance.expects(:handle_clicked_event).never
    campaign_email.event_logs.create!(
        :event_type => CampaignManagement::EmailEventLog::Type::OPENED,
        :timestamp => Time.at(Time.now.strftime('%s').to_i)
    )
  end
end