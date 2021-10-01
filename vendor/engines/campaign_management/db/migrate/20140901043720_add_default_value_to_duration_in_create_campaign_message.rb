class AddDefaultValueToDurationInCreateCampaignMessage < ActiveRecord::Migration[4.2]

  def change
    change_column :cm_campaign_messages, :duration, :integer, :default => 0
    CampaignManagement::AbstractCampaignMessage.reset_column_information
  end
end
