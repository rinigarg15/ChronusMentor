module CronTasks
  module CampaignManagement
    class JobsProcessor
      include Delayed::RecurringJob

      def perform
        ::CampaignManagement::CampaignMessageJobProcessor.process
      end
    end
  end
end