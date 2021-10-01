class CreateCampaignsInActiveMode < ActiveRecord::Migration[4.2]

  def up
  	change_column_default(:cm_campaigns, :state, CampaignManagement::AbstractCampaign::STATE::ACTIVE)
    CampaignManagement::AbstractCampaign.reset_column_information
  end

  def down
  	change_column_default(:cm_campaigns, :state, CampaignManagement::AbstractCampaign::STATE::STOPPED)
    CampaignManagement::AbstractCampaign.reset_column_information
  end
end
