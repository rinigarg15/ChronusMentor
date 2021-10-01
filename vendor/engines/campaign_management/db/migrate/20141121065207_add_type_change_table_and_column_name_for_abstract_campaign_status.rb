class AddTypeChangeTableAndColumnNameForAbstractCampaignStatus < ActiveRecord::Migration[4.2]

  def up
    add_column :cm_campaign_user_statuses, :type, :text
    rename_column :cm_campaign_user_statuses, :user_id, :abstract_object_id
    rename_table :cm_campaign_user_statuses, :cm_campaign_statuses
    CampaignManagement::AbstractCampaignStatus.reset_column_information
    CampaignManagement::AbstractCampaignStatus.update_all(:type => "CampaignManagement::UserCampaignStatus")
  end

  def down
    rename_table :cm_campaign_statuses, :cm_campaign_user_statuses
    rename_column :cm_campaign_user_statuses, :abstract_object_id, :user_id
    remove_column :cm_campaign_user_statuses, :type
  end
end
