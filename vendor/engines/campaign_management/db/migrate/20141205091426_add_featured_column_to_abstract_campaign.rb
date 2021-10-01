class AddFeaturedColumnToAbstractCampaign < ActiveRecord::Migration[4.2]

  def up
    add_column :cm_campaigns, :featured, :boolean, :default => false
    CampaignManagement::AbstractCampaign.reset_column_information
  end

  def down
    remove_column :cm_campaigns, :featured
  end
end
