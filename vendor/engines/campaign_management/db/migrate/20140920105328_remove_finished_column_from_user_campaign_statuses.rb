class RemoveFinishedColumnFromUserCampaignStatuses < ActiveRecord::Migration[4.2]

  def up
    remove_column :cm_campaign_user_statuses, :finished
    # CampaignManagement::UserCampaignStatus.reset_column_information
  end

  def down
  end
end
