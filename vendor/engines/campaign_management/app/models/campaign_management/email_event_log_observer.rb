class CampaignManagement::EmailEventLogObserver < ActiveRecord::Observer
  def after_create(email_event_log)
    email_event_log.update_analytics_summary_of_campaign_message
    email_event_log.handle_clicked_event if email_event_log.event_type == CampaignManagement::EmailEventLog::Type::CLICKED
  end
end