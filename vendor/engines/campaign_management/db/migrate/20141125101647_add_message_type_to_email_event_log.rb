class AddMessageTypeToEmailEventLog < ActiveRecord::Migration[4.2]

  def up
    add_column :cm_email_event_logs, :message_type, :text
    CampaignManagement::EmailEventLog.update_all(:message_type => CampaignManagement::UserCampaign.to_s)
  end

  def down
    remove_column :cm_email_event_logs, :message_type, :text
  end
end
