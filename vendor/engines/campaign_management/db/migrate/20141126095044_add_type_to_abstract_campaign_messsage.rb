class AddTypeToAbstractCampaignMesssage < ActiveRecord::Migration[4.2]

  def up
    add_column :cm_campaign_messages, :type, :text
    CampaignManagement::AbstractCampaignMessage.reset_column_information
    CampaignManagement::AbstractCampaignMessage.update_all(:type => "CampaignManagement::UserCampaignMessage")
  end
  
  def down
    remove_column :cm_campaign_messages, :type
  end
end
