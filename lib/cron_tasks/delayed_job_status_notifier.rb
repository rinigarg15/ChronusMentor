module CronTasks
  class DelayedJobStatusNotifier
    include Delayed::RecurringJob

    def perform
      DjNotifier.new.notify_status
    end
  end
end