# Sends the weekly site status of all programs to admins.
module CronTasks
  class WeeklyStatusMailer
    include Delayed::RecurringJob

    def perform
      Notify.admins_weekly_status
    end
  end
end