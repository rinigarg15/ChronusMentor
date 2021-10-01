class AddAnalyticSummaryToCampaignMessage < ActiveRecord::Migration[4.2]

  def change
    add_column :cm_campaign_messages, :analytics_summary, :text
  end
end
