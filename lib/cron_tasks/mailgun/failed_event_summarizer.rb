module CronTasks
  module Mailgun
    class FailedEventSummarizer
      include Delayed::RecurringJob

      def perform
        ChronusMentorMailgun::FailedEventSummarizer.new(1).summarize
      end
    end
  end
end