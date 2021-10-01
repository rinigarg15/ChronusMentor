# == Schema Information
#
# Table name: job_logs
#
#  id                   :integer          not null, primary key
#  ref_obj_id           :integer
#  loggable_object_id   :integer
#  loggable_object_type :string(255)
#  action_type          :integer
#  version_id           :integer
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  ref_obj_type         :string(255)
#  job_uuid             :string(255)
#

class JobLog < ActiveRecord::Base
  belongs_to :loggable_object, polymorphic: true
  belongs_to :ref_obj, polymorphic: true

  validates :action_type, :ref_obj_id, :ref_obj_type, :loggable_object_id, :loggable_object_type, presence: true, unless: :job_uuid?
  validates :job_uuid, presence: true, if: :job_log_validatable?
  validates :ref_obj_id, uniqueness: { scope: [:loggable_object_id, :loggable_object_type, :action_type, :version_id, :job_uuid, :ref_obj_type] }, presence: true

  def self.compute_with_historical_data(ref_objects, object, action_type, version_number = nil, options = {})
    raise "No block given" unless block_given?
    ref_object_hashed_logs = get_logs(object, action_type, version_number, options)
    jl_processes = 4
    jl_slice_size = 1000
    process_in_batches(ref_objects, jl_processes*jl_slice_size, options) do |ref_objects_batch|
      # Note: parallel processing cannot be done when joblog is inside a transaction - activerecord:connection reconnects!
      process_in_parallel(ref_objects_batch, jl_processes, options) do |ref_object, index|
        begin
          log_data = "#{Time.now.strftime('%FT%T%z')}: #{concatenated_string(object, options)} ##{ref_object.id} "
          if ref_object_hashed_logs[ref_object.id].nil?
            yield(ref_object)
            ref_object_hashed_logs[ref_object.id] = Array(create_log_record!(ref_object, object, action_type, version_number, options))
            log_info log_data + "Completed: #{index + 1}"
          else
            log_info log_data + "Skipping: #{index + 1}"
          end
        rescue => exception
          error_message = "JobLog: #{concatenated_string(object, options)} - #{action_type} failed for #{ref_object.class.name} #{ref_object.id} with exception #{exception.message}"
          Airbrake.notify(error_message)
        end
      end
    end
  end

  # + objects + should typically be a ActiveRecord::Relation object and not an array for perf reasons
  # The method is anyway supported for non-ActiveRecord::Relation objects as well
  def self.compute_with_uuid(objects, job_uuid, entity = "")
    raise "No block given" unless block_given?
    hashed_logs = job_uuid.present? ? where(job_uuid: job_uuid).group_by(&:ref_obj_id) : {}
    index = 0
    object_entities, finder_method = process_objects(objects)
    object_entities.send(finder_method) do |object|
      index += 1
      log_data = "#{index}. #{object.class.name}: #{object.id} | Job UUID: #{job_uuid} #{entity}"
      if hashed_logs[object.id].nil?
        yield(object)
        hashed_logs[object.id] = Array(object.job_logs.create!(job_uuid: job_uuid)) if job_uuid.present?
        log_info "Completed: #{log_data}"
      else
        log_info "Skipping: #{log_data}"
      end
    end
  end

  # When generating the uuid, we are not cross-checking the delayed_jobs handler
  # to make sure the generated uuid's are unique. As it is a proven fact that the
  # SecureRandom.uuid implemented based on http://www.ietf.org/rfc/rfc4122.txt
  # SO Article: http://stackoverflow.com/questions/16650764/securerandom-uuid-vs-uuid-gem
  # But still having a method, so that we can modify this, if we decide to change the approach or go for a better UUID generator :)
  def self.generate_uuid
    SecureRandom.uuid
  end

  def self.log_info(data, dj_log = true)
    if dj_log && Delayed::Worker.logger
      Delayed::Worker.logger.add Logger::INFO, data
    elsif respond_to?(:logger)
      logger.info data
    elsif !Rails.env.test?
      puts data
    end
  end

  private

  def self.process_in_batches(ref_objects, batch_size, options)
    if options[:batch_processing]
      if ref_objects.is_a?(ActiveRecord::Relation)
        ref_objects.find_in_batches(:batch_size => batch_size) do |ref_objects_batch|
          yield(ref_objects_batch)
        end
      else
        ref_objects.each_slice(batch_size) do |ref_objects_slice|
          yield(ref_objects_slice)
        end
      end
    else
      yield(ref_objects)
    end
    ActiveRecord::Base.connection.reconnect! if options[:parallel_processing] && !Rails.env.test?
  end

  def self.process_in_parallel(ref_objects, num_processes, options)
    if options[:parallel_processing]
      Parallel.each_with_index(ref_objects, :in_processes => num_processes) do |ref_object_parallel, index|
        @reconnected ||= ActiveRecord::Base.connection.reconnect!
        yield ref_object_parallel, index
      end
    else
      ref_objects.each_with_index do |ref_object, index|
        yield ref_object, index
      end
    end
  end

  def self.process_objects(objects)
    if objects.is_a?(ActiveRecord::Relation)
      [objects, :find_each]
    else
      [Array(objects), :each]
    end
  end

  def self.concatenated_string(object, options)
    "#{options[:klass_name] || object.class.name}##{options[:klass_id] || object.id}"
  end

  def self.get_logs(object, action_type, version_number, options)
    JobLog.where(action_type: action_type, version_id: version_number,
      loggable_object_type: options[:base_klass_name] || options[:klass_name] || object.class.name,
      loggable_object_id: options[:klass_id] || object.id).group_by(&:ref_obj_id)
  end

  def self.create_log_record!(ref_object, object, action_type, version_number, options)
    JobLog.create!(ref_obj_id: ref_object.id, ref_obj_type: ref_object.class.name, action_type: action_type, version_id: version_number,
      loggable_object_type: options[:base_klass_name] || options[:klass_name] || object.class.name,
      loggable_object_id: options[:klass_id] || object.id)
  end

  def job_log_validatable?
    action_type.nil? && loggable_object_id.nil? && loggable_object_type.nil?
  end

end
