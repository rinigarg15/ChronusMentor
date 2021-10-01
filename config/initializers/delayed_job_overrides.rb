# Delayed Job gems were vendorised and the following fixes were made on the vendorized gem.
# Moved these fixes here after Delayed Job was upgraded as part of Ruby 2 Upgrade

module Delayed
  class Worker

    attr_accessor :job_group_id

    # Logs the Active Record object ID when Deserialization Errors occur when running DJs
    def run(job)
      job_say job, 'RUNNING'
      # Set the source priority for the djs created from this dj
      Delayed::Job.source_priority = job.source_priority.to_i
      Delayed::Job.organization_id = job.organization_id
      runtime =  Benchmark.realtime do
        Timeout.timeout(max_run_time(job).to_i, WorkerTimeout) { job.invoke_job }
        job.destroy
      end
      job_say job, format('COMPLETED after %.4f', runtime)
      return true  # did work
    rescue DeserializationError => error
      job.last_error = "#{error.message}\n#{error.backtrace.join("\n")}"
      log_job_with_deserialization_error(job, error)
      failed(job)
    rescue => error
      self.class.lifecycle.run_callbacks(:error, self, job) { handle_failed_job(job, error) }
      return false  # work failed
    end

    def log_job_with_deserialization_error(job, error)
      job_say job, "- failed with #{error.class.name}: #{error.message} - #{job.handler}", Logger::ERROR
    end

    # ActiveJob will reload codes if necessary. DelayedJob consumes CPU and memory for reloading on every 5 secs.
    # TODO: https://github.com/collectiveidea/delayed_job/issues/776#issuecomment-307161178
    def self.reload_app?
      false
    end
  end

  module Backend
    module ActiveRecord
      class Job

        # Reserve with scope update query was optimized for performance which sometimes causes LockWaitTimeout and DeadLocks under heavy load.
        # This reverts to the old unoptimized queries which are reliable
        # https://github.com/collectiveidea/delayed_job_active_record/issues/63
        # https://gist.github.com/cainlevy/c6cfa67d44fe7427dea6
        class << self
          alias_method :reserve_with_scope, :reserve_with_scope_using_default_sql
          attr_accessor :source_priority, :organization_id
        end

        before_create :set_priority, :set_organization_id

        def set_priority
          self.source_priority = Delayed::Job.source_priority.to_i
          self.priority = (self.priority.to_i - Delayed::Job.source_priority.to_i)
        end

        def set_organization_id
          self.organization_id = Delayed::Job.organization_id if Delayed::Job.organization_id.present?
        end

        # Non-named queue workers should not pick named queue jobs
        def self.reserve(worker, max_run_time = Worker.max_run_time) # rubocop:disable CyclomaticComplexity
          # scope to filter to records that are "ready to run"
          ready_scope = ready_to_run(worker.name, max_run_time)

          # scope to filter to the single next eligible job
          ready_scope = ready_scope.where("priority >= ?", Worker.min_priority) if Worker.min_priority
          ready_scope = ready_scope.where("priority <= ?", Worker.max_priority) if Worker.max_priority
          ready_scope = ready_scope.where(job_group_id: worker.job_group_id) if worker.job_group_id

          # Remove djs with job_group_id whose number of currently running djs equals to max_workers.
          max_working_job_group_ids = Delayed::Job.where("locked_at IS NOT NULL AND failed_at IS NULL AND job_group_id IS NOT NULL AND max_workers IS NOT NULL")
          .group(:job_group_id, :max_workers).having("count(id) >= max_workers").pluck(:job_group_id)
          ready_scope = ready_scope.where.not(job_group_id: max_working_job_group_ids)

          if worker.job_group_id.nil?
            if Worker.queues.any?
              ready_scope = ready_scope.where(queue: Worker.queues)
            else
              ready_scope = ready_scope.where(queue: nil)
            end
          end
          ready_scope = ready_scope.by_priority

          reserve_with_scope(ready_scope, worker, db_time_now)
        end
      end
    end
  end
end