module CronTasks
  module CampaignManagement
    class CampaignsStarter
      include Delayed::RecurringJob

      def perform
        ::CampaignManagement::CampaignProcessor.instance.start
      end
    end
  end
end