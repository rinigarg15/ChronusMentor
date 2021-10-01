class CampaignManagement::CampaignMessageJobProcessor

  PROCESSORS = 4

  def self.process
    start_time = Time.now
    Rails.logger.info "Starting Campaign Message Job Processor: #{start_time}"

    active_program_ids = Program.active.pluck(:id)
    active_campaigns_id = CampaignManagement::AbstractCampaign.active.where(program_id: active_program_ids).pluck(:id)
    campaign_messages_id = CampaignManagement::AbstractCampaignMessage.where(campaign_id: active_campaigns_id).pluck(:id)
    pending_jobs = CampaignManagement::AbstractCampaignMessageJob.pending.ready_to_be_executed.where(campaign_message_id: campaign_messages_id)
    pending_jobs_count = pending_jobs.count
    bulk_send_campaign_messages(pending_jobs)
    end_time = Time.now
    Rails.logger.info "Finishing Campaign Message Job Processor: #{end_time}"
    Rails.logger.info "Time taken for Campaign Message Job Processor for (#{pending_jobs_count}) jobs: #{end_time - start_time}"
  end

  def self.remove_duplicate_pending_jobs(pending_jobs)
    return [] unless pending_jobs.present?
    duplicate_jobs = pending_jobs.group_by{|job| [job.campaign_message_id, job.abstract_object_id, job.abstract_object_type]}.select{|_k, v| v.size > 1 }
    notify_airbrake_for_duplicate_jobs if duplicate_jobs.present?
    duplicate_jobs.each do |_group_by, jobs|
      valid_job = jobs[0]
      jobs[1..-1].each do |duplicate_job|
        pending_jobs -= [duplicate_job]
        duplicate_job.delete
      end
    end
    pending_jobs
  end

  # The name of the funciton is being left as it is, although it does a individual send

  def self.bulk_send_campaign_messages(pending_jobs, options = {})
    pending_jobs_without_duplicates = remove_duplicate_pending_jobs(Array(pending_jobs))
    return [] unless pending_jobs_without_duplicates.present?

    return send_campaign_messages(pending_jobs_without_duplicates) if options[:skip_parallel_processing].present?

    pending_job_sets = pending_jobs_without_duplicates.each_slice((pending_jobs_without_duplicates.count.to_f/PROCESSORS).ceil).to_a
    Parallel.each(pending_job_sets, in_processes: PROCESSORS) do |pending_job_set|
      send_campaign_messages(pending_job_set)
    end
  end

  def self.send_campaign_messages(pending_jobs)
    begin
      pending_jobs.each do |job|
        job.with_lock do
          if CampaignManagement::AbstractCampaignMessageJob.exists?(job.id) && !job.failed?
            if job.create_personalized_message
              job.delete
            else
              job.update_columns(failed: true, skip_delta_indexing: true)
            end
          end
        end
      end
    rescue => ex
      raise ex
    end
  end

  def self.notify_airbrake_for_duplicate_jobs
    log_text = "Duplicate Jobs encountered while processing campaign message jobs"
    Airbrake.notify(log_text)
    Rails.logger.info log_text
  end
end