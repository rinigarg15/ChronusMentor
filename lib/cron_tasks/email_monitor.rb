module CronTasks
  class EmailMonitor
    include Delayed::RecurringJob

    def perform
      ::EmailMonitor.new.send_email
    end
  end
end