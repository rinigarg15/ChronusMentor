class RenameColumnFromCountToEventCountInCampaignMessageAnalytics < ActiveRecord::Migration[4.2]

  def up
    rename_column :cm_campaign_message_analytics, :count, :event_count
  end

  def down
    rename_column :cm_campaign_message_analytics, :event_count, :count
  end
end
