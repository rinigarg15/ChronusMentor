class AddEnabledAtToAbstractCampaign < ActiveRecord::Migration[4.2]

  def up
    add_column :cm_campaigns, :enabled_at, :datetime
    CampaignManagement::AbstractCampaign.update_all("enabled_at=created_at")
  end

  def down
    remove_column :cm_campaigns, :enabled_at
  end
end
