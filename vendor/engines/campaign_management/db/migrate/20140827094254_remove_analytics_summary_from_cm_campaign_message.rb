class RemoveAnalyticsSummaryFromCmCampaignMessage < ActiveRecord::Migration[4.2]

  def up
    remove_column :cm_campaign_messages, :analytics_summary
    CampaignManagement::AbstractCampaignMessage.reset_column_information
  end

  def down
    add_column :cm_campaign_messages, :analytics_summary, :text
    CampaignManagement::AbstractCampaignMessage.reset_column_information
  end
end
