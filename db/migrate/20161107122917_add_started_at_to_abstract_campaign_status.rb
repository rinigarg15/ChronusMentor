class AddStartedAtToAbstractCampaignStatus< ActiveRecord::Migration[4.2]
  def up
    add_column :cm_campaign_statuses, :started_at, :datetime
    CampaignManagement::AbstractCampaignStatus.update_all("started_at=created_at")
  end

  def down
    remove_column :cm_campaign_statuses, :started_at
  end
end
