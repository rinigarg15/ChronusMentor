module CronTasks
  class Monitor
    include Delayed::RecurringJob

    def perform
      tasks_off_schedule = CronTasksScheduler.tasks_off_schedule
      Airbrake.notify("The following tasks are off schedule: #{tasks_off_schedule.join(COMMON_SEPARATOR)}") if tasks_off_schedule.any?
      CronMonitor::Signal.new(CronMonitorConstants::CRON_TASKS_MONITOR).trigger if APP_CONFIG[:should_trigger_cron_monitor_notification]
    end
  end
end