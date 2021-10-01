class AddUserJobsCreatedToCampaignMessage < ActiveRecord::Migration[4.2]

  def change
    add_column :cm_campaign_messages, :user_jobs_created, :boolean, :default => false
    CampaignManagement::AbstractCampaignMessage.reset_column_information
  end
end
