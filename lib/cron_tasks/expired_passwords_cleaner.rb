module CronTasks
  class ExpiredPasswordsCleaner
    include Delayed::RecurringJob

    def perform
      Password.destroy_expired
    end
  end
end