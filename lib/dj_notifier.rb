class DjNotifier
  attr_accessor :jobs, :current_time, :job_stats, :queue_stats

  module JobCategory
    FAILED = :failed
    STUCK = :stuck

    def self.all
      [FAILED, STUCK]
    end
  end

  BUFFER_TIME = {
    DjQueues::ES_DELTA => 45.minutes,
    DjQueues::MONGO_CACHE => 60.minutes,
    DjQueues::MONGO_CACHE_HIGH_LOAD => 120.minutes,
    DjQueues::LONG_RUNNING => 120.minutes
  }

  def initialize
    self.jobs = Delayed::Job.order(priority: :desc)
    self.current_time = Time.now

    self.job_stats = {}
    self.queue_stats = {}
    JobCategory.all.each do |job_category|
      self.job_stats[job_category] = []
      self.queue_stats[job_category] = {}
    end
  end

  def notify_status
    compute_stats

    if self.job_stats.values.flatten.size > 0
      InternalMailer.notify_dj_status(self).deliver_now
    end
  end

  private

  def compute_stats
    self.jobs.each do |job|
      job_category = get_job_category(job)

      unless job_category.nil?
        queue = job.queue || DjQueues::NORMAL

        self.job_stats[job_category] << job_info(job)
        self.queue_stats[job_category][queue] ||= 0
        self.queue_stats[job_category][queue] += 1
      end
    end
  end

  def job_info(job)
    job_info = { "Job ID" => job.id }
    job_info.merge!("Last Error" => job.last_error.truncate(500)) if job.last_error.present?
    job_info.merge!("Job Handler" => job_handler_info(job))
  end

  def job_handler_info(job)
    begin
      payload = YAML.load_dj(job.handler)
      if payload.is_a?(Delayed::RecurringJob)
        return {
          "Class" => payload.class.to_s,
          "Run At" => job.run_at
        }
      else
        payload_object = payload.object
        return {
          "Class" => payload_object.respond_to?(:id) ? payload_object.class.to_s : payload_object.to_s,
          "Object ID" => payload_object.try(:id),
          "Method" => payload.method_name,
          "Args" => payload.args
        }
      end
    rescue => e
      return job.handler.to_s.truncate(500)
    end
  end

  def get_job_category(job)
    return JobCategory::FAILED if is_failed_job?(job)
    return JobCategory::STUCK if is_stuck_job?(job)
  end

  def get_buffer_time(job)
    BUFFER_TIME[job.queue] || 45.minutes
  end

  def is_failed_job?(job)
    job.last_error.present?
  end

  def is_stuck_job?(job)
    return false if job.last_error.present?
    return false if job.queue == DjQueues::AWS_ELASTICSEARCH_SERVICE

    ((job.run_at || job.created_at) + get_buffer_time(job)) < self.current_time
  end
end