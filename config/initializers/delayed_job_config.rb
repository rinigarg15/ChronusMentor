Delayed::Worker.destroy_failed_jobs = false
Delayed::Worker.max_attempts = 1
Delayed::Worker.max_run_time = 48.hours
# If no jobs are found, the worker sleeps for the amount of time specified by the sleep delay option. By default, it is 5 seconds. 
Delayed::Worker.sleep_delay = 0.2
Delayed::Worker.delay_jobs = !Rails.env.test?
# Lower the default priority from 0 to 5 so that delayed jobs submitted by app thru send_later
# run with priority lower than sphinx delta delayed jobs. 
# sphinx delta delayed jobs run with priority 0. See sphinx.yml
Delayed::Worker.default_priority = 5
Delayed::Worker.logger = Logger.new(File.join(Rails.root, 'log', 'delayed_job.log'))

class DjCallback < Delayed::Plugin
  callbacks do |lifecycle|
    lifecycle.after(:perform) do |worker, job|
      Delayed::Worker.logger.debug("After perform: resetting locale from #{I18n.locale} to #{I18n.default_locale} #{Rails.env}") unless Rails.env.test?
      I18n.locale = I18n.default_locale
    end
  end
end
     
Delayed::Worker.plugins << DjCallback