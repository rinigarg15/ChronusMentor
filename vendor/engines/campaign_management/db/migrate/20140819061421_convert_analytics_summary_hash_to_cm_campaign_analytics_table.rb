class ConvertAnalyticsSummaryHashToCmCampaignAnalyticsTable < ActiveRecord::Migration[4.2]

  def change
    campaign_messages = CampaignManagement::AbstractCampaignMessage.all
    ActiveRecord::Base.transaction do
      campaign_messages.each do |campaign_message|
        analytics_summary = campaign_message.analytics_summary
        analytics_summary.try(:each) do |month, summaries|
          summaries.try(:each) do |event_type, count|
            campaign_message.campaign_message_analyticss.create!(:year_month => month, :event_type => event_type, :count => count)
          end
        end
      end
    end
  end
end
