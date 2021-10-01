module DJUtils
  class DJUtilsProxy
    def initialize(options)
      @options = options
    end

    def create_elasticsearch_indexer_job(klass, id, method_name, partial_indices, includes_list)
      delayed_job_object = ElasticsearchIndexerJob.new(klass, id, method_name, partial_indices, includes_list)
      enqueue_dj_unless_duplicate(delayed_job_object, klass, method_name)
    end

    def method_missing(method_name, object, *args)
      delayed_job_object = Delayed::PerformableMethod.new(object, method_name.to_sym, args)
      enqueue_dj_unless_duplicate(delayed_job_object, object, method_name)
    end

    private

    def enqueue_dj_unless_duplicate(delayed_job_object, object, method_name)
      enqueued_jobs = Delayed::Job.where(@options).where(handler: delayed_job_object.to_yaml, locked_at: nil, failed_at: nil)
      if enqueued_jobs.empty?
        Delayed::Job.enqueue(delayed_job_object, @options)
      else
        Rails.logger.info "Duplicate job prevented: #{object} #{method_name}"
      end
    end
  end

  def self.enqueue_unless_duplicates(options = {})
    DJUtilsProxy.new(options)
  end
end