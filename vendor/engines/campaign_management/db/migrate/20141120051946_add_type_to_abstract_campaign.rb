class AddTypeToAbstractCampaign < ActiveRecord::Migration[4.2]

  def up
    add_column :cm_campaigns, :type, :text
    CampaignManagement::AbstractCampaign.reset_column_information
    CampaignManagement::AbstractCampaign.update_all(:type => "CampaignManagement::UserCampaign")
  end
  
  def down
    remove_column :cm_campaigns, :type
  end
end
