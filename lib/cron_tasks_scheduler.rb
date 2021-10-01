module CronTasksScheduler
  extend DjSourcePriorityHelper

  def self.schedule
    self.iterate_over_schedule_map do |cron_task, schedule_options|
      set_cron_dj_priority(schedule_options[:queue] == DjQueues::HIGH_PRIORITY)
      cron_task.schedule(schedule_options)
    end
  end

  def self.tasks_off_schedule
    tasks_off_schedule = []
    self.iterate_over_schedule_map do |cron_task, schedule_options|
      if cron_task.jobs(schedule_options).size != 1
        job_matching_param = schedule_options[:job_matching_param]
        job_matching_info = " - #{job_matching_param}: #{schedule_options[job_matching_param.to_sym]}" if job_matching_param.present?
        tasks_off_schedule << "#{cron_task}#{job_matching_info}"
      end
    end
    tasks_off_schedule
  end

  def self.iterate_over_schedule_map
    self.schedule_map.each do |cron_task, schedule_options_ary|
      [schedule_options_ary].flatten.each do |schedule_options|
        schedule_options.deep_symbolize_keys!
        tz_schedule_options = schedule_options.delete(:use_region_specific_tz) ? { timezone: APP_CONFIG[:cron_timezone] } : {}
        yield(cron_task.constantize, schedule_options.merge(tz_schedule_options))
      end
    end
  end

  def self.schedule_map
    YAML::load(ERB.new(File.read("#{Rails.root}/config/cron_tasks.yml")).result)[Rails.env]
  end
end