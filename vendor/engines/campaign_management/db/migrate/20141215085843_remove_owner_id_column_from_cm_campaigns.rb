class RemoveOwnerIdColumnFromCmCampaigns < ActiveRecord::Migration[4.2]

  def up
    remove_column :cm_campaigns, :owner_id
    CampaignManagement::AbstractCampaign.reset_column_information
  end

  def down
    add_column :cm_campaigns, :owner_id, :integer
    CampaignManagement::AbstractCampaign.reset_column_information
  end
end
