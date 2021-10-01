class RemoveDelayedJobIdFromUserCampaignMessageJob < ActiveRecord::Migration[4.2]

  def up
    remove_column :cm_campaign_message_user_jobs, :delayed_job_id
    #CampaignManagement::UserCampaignMessageJob.reset_column_information
  end

  def down
  add_column :cm_campaign_message_user_jobs, :delayed_job_id, :integer
    #CampaignManagement::UserCampaignMessageJob.reset_column_information
  end
end
