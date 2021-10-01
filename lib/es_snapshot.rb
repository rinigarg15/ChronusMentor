module EsSnapshot
  # TODO: Once we got elastic search service specific to each environment, then we can get rid of ALLOWED_ENVIRONMENTS
  ALLOWED_ENVIRONMENTS = ["staging", "production", "productioneu"]

  # As all the staging environments point to the same Elasticsearch Domain, we should take snapshot only once.
  def self.create
    flush_aws_dj_entries
    return unless Rails.env.in? ALLOWED_ENVIRONMENTS

    client = ElasticsearchReindexing.configure_client
    time_now =  DateTime.localize(Time.now, format: :full_date_full_time).to_s.gsub(' ', '_')
    snapshot_name = "es-snapshot-#{Rails.env.downcase}-#{time_now}"
    create_s3_respository(client, snapshot_name)
    client.snapshot.create repository: AWS_ES_OPTIONS[:s3_repository], snapshot: snapshot_name
  end

  # As all the staging environments point to the same Elasticsearch Domain, we should restore snapshot only once.
  def self.restore(snapshot_name)
    if ALLOWED_ENVIRONMENTS.include?(Rails.env)
      raise "SNAPSHOT_NAME is not specified" unless snapshot_name.present?

      client = ElasticsearchReindexing.configure_client
      indices_hash = client.indices.get index: '_all'
      client.indices.delete index: indices_hash.keys if indices_hash.keys.present?
      create_s3_respository(client, snapshot_name)
      client.snapshot.restore repository: AWS_ES_OPTIONS[:s3_repository], snapshot: snapshot_name
    end
    # Though restoring snapshot is made only once, applying the delta jobs should be done in each of the environment.
    run_delta_jobs_in_aws_dj_queue
  end

  def self.check_status(snapshot_name)
    raise "SNAPSHOT_NAME is not specified" unless snapshot_name.present?

    client = ElasticsearchReindexing.configure_client
    client.snapshot.status repository: AWS_ES_OPTIONS[:s3_repository], snapshot: snapshot_name, human: true
  end

  def self.flush_aws_dj_entries
    # Flush the entries in DjQueues::AWS_ELASTICSEARCH_SERVICE only if it is already processed in the regular queue.
    total_entries_in_aws_es_queue = Delayed::Job.where(queue: DjQueues::AWS_ELASTICSEARCH_SERVICE)
    pending_es_entries_in_regular_queue = Delayed::Job.where(queue: DjQueues::ES_DELTA, handler: total_entries_in_aws_es_queue.pluck(:handler))
    total_entries_in_aws_es_queue.where.not(handler: pending_es_entries_in_regular_queue.pluck(:handler)).delete_all
    remove_duplicates_among_non_deleted_djs(total_entries_in_aws_es_queue)
  end

  def self.run_delta_jobs_in_aws_dj_queue
    aws_es_dj_entries = Delayed::Job.where(queue: DjQueues::AWS_ELASTICSEARCH_SERVICE)
    aws_es_dj_entries.each do |dj_entry|
      dj_entry.invoke_job
      dj_entry.destroy
    end
  end

  def self.create_s3_respository(client, snapshot_name)
    client.snapshot.create_repository repository: AWS_ES_OPTIONS[:s3_repository], body: { type: "s3", settings: {bucket: AWS_ES_OPTIONS[:s3_bucket], region: AWS_ES_OPTIONS[:s3_region], role_arn: AWS_ES_OPTIONS[:s3_access_role], base_path: snapshot_name} }
  end

  def self.remove_duplicates_among_non_deleted_djs(total_entries_in_dj_queue)
    # Remove duplicates among the not deleted dj entries present in the aws queue
    entries_not_deleted_in_dj_queue = total_entries_in_dj_queue.reload.group_by(&:handler).values
    entries_not_deleted_in_dj_queue.each do |duplicates|
      duplicates.shift
      Delayed::Job.where(id: duplicates.collect(&:id)).delete_all
    end
  end
end