class AddTypeChangeTableAndColumnNameForAbstractCampaignMessageJob < ActiveRecord::Migration[4.2]

  def up
    add_column :cm_campaign_message_user_jobs, :type, :text
    rename_column :cm_campaign_message_user_jobs, :user_id, :abstract_object_id
    rename_table :cm_campaign_message_user_jobs, :cm_campaign_message_jobs
    CampaignManagement::AbstractCampaignMessageJob.reset_column_information
    CampaignManagement::AbstractCampaignMessageJob.update_all(:type => "CampaignManagement::UserCampaignMessageJob")
  end

  def down
    rename_table :cm_campaign_message_jobs, :cm_campaign_message_user_jobs
    rename_column :cm_campaign_message_user_jobs, :abstract_object_id, :user_id
    remove_column :cm_campaign_message_user_jobs, :type
  end
end
