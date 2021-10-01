module NewRelicAgentSamplersDelayedJobSamplerWithModification
  def record_queue_length_metrics
    record_not_yet_completed
    super
  end

  def record_not_yet_completed
    DjQueues::SLA.each do |queue_name, source_hash|
      source_hash.each do |source, sla_val|
        metric = "Workers/DelayedJob/not_yet_completed_sla_violations/name/#{queue_name}/#{source}"
        count = count_jobs_delayed_greaterthan_x((queue_name == DjQueues::NORMAL ? nil : queue_name), sla_val, source)
        NewRelic::Agent.record_metric(metric, count)
      end
    end
  end

  def count_jobs_delayed_greaterthan_x(queue_name, sla_val, source)
    ::Delayed::Job.where(queue: queue_name).where('run_at <= ? and source_priority = ? and failed_at is NULL', sla_val.ago, source).count
  end
end

NewRelic::Agent::Samplers::DelayedJobSampler.prepend(NewRelicAgentSamplersDelayedJobSamplerWithModification)