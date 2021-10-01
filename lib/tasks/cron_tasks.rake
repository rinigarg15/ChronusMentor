namespace :cron_tasks do
  task schedule: :environment do
    CronTasksScheduler.schedule
  end
end