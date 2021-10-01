class CmAddRequiredFieldsForDjToCronMigration < ActiveRecord::Migration[4.2]

  def up
    add_column :cm_campaign_message_user_jobs, :run_at, :datetime, :default => nil
    add_column :cm_campaign_message_user_jobs, :failed, :boolean, :default => false
    # CampaignManagement::UserCampaignMessageJob.reset_column_information
  end

  def down
    remove_column :cm_campaign_message_user_jobs, :run_at
    remove_column :cm_campaign_message_user_jobs, :failed
    # CampaignManagement::UserCampaignMessageJob.reset_column_information
  end
end
