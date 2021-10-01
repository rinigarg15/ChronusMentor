class SetMessageTypeToUserCampaignForExistingCampaigns < ActiveRecord::Migration[4.2]

  def up
    CampaignManagement::EmailEventLog.update_all(:message_type => CampaignManagement::EmailEventLog::MessageType::ADMIN_MESSAGE)
  end

  def down
  end
end
