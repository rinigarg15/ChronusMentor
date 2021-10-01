# Fetches analytics from the Mailgun
module CronTasks
  module CampaignManagement
    class AnalyticsSynchronizer
      include Delayed::RecurringJob

      def perform
        ::CampaignManagement::CampaignAnalyticsSynchronizer.instance.sync
      end
    end
  end
end