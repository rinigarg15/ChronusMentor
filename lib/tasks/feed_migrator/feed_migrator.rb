module FeedMigrator
  # Migrator related constant

  CHARACTER_ENCODING = "UTF-8" unless defined?(CHARACTER_ENCODING)

  # Error handling support classes
  class UnsupportedProfileQuestiontype < StandardError
    attr_accessor :invalid_profile_questions
    def initialize(invalid_profile_questions_ary)
      @invalid_profile_questions = invalid_profile_questions_ary
    end
  end

  class InvalidRowData < StandardError
    attr_accessor :error_objects
    def initialize(error_objects_ary)
      @error_objects = error_objects_ary
    end
    class Error
      attr_accessor :error_object, :row, :message
      def initialize(info = {})
        @error_object = info[:error_obj]
        @row = info[:row]
        @message = info[:message]
      end
    end
  end

  class InvalidRowHeaders < StandardError
    attr_accessor :invalid_headers
    def initialize(invalid_headers_ary)
      @invalid_headers = invalid_headers_ary
    end
  end

  def get_failure_message_from_error(error)
    ret = ""
    case error
    when CSV::MalformedCSVError
      ret << "Malformed CSV File: #{error.message}"
    when UnsupportedProfileQuestiontype
      ret << "Unsupported Type Questions: "
      ret << error.invalid_profile_questions.collect{|pq| "'#{pq.question_text}'"}.to_sentence
    when InvalidRowData
      ret << "The following rows contains invalid data:\n"
      error.error_objects.each do |obj|
        ret << "Row #{obj.row}. #{obj.message} #{"(Answer: '#{obj.error_object.answer_text}')" if obj.error_object.is_a?(ProfileAnswer)}\n"
      end
    when InvalidRowHeaders
      ret << "Invalid Headers Not Matching Profile Fields: "
      ret << error.invalid_headers.to_sentence
    end
    ret
  end

  # just a precautionery logger method, incase we need to expand in future easily
  def feed_migrator_logger(str, options = {})
    puts str
  end

  def set_credentials_and_get_bucket_name
    s3_credentials = YAML::load(ERB.new(File.read("#{Rails.root.to_s}/config/s3.yml")).result)[Rails.env]
    s3_credentials["customer_feed_bucket"]
  end

  def establish_connection_and_get_bucket(bucket_name)
    ChronusS3Utils::S3Helper.get_bucket(bucket_name)
  end

  def fill_org_level_migration_status_if_absent(org_level_migration_status, sftp_user_name, organization)
    org_level_migration_status[sftp_user_name] = {}
    org_level_migration_status[sftp_user_name][:organization] = organization
    org_level_migration_status[sftp_user_name][:skipped_migrations] = []
    org_level_migration_status[sftp_user_name][:main_migration] = []
  end

  def get_source_keys_directory(sftp_user_name, source_info)
    source_directory = File.join(sftp_user_name, File.join("latest", source_info[:source].to_s))
    keys_directory = File.join(sftp_user_name, "secret_keys")
    [source_directory, keys_directory]
  end

  def get_objects_to_be_archived(bucket, source_directory)
    bucket.objects.with_prefix(source_directory).select{|o| File.basename(o.key).match(/\d+_(.*)/)}
  end

  def get_keys_for_migration(bucket, keys_directory)
    bucket.objects.with_prefix(keys_directory).select { |obj| !(obj.key =~ /\/$/) }
  end

  def get_local_file_name(sftp_user_name, object)
    File.join('', 'tmp', sftp_user_name + '_tmp_' + File.basename(object.key))
  end

  def get_feed_object_from_objects_to_be_archived(objects_to_be_archived)
    objects_to_be_archived.sort_by(&:key).reverse[0]
  end

  def get_objects_to_be_archived_and_keys_for_migration(bucket, sftp_user_name, source_info)
    source_directory, keys_directory = get_source_keys_directory(sftp_user_name, source_info)
    objects_to_be_archived = get_objects_to_be_archived(bucket, source_directory)
    keys_for_migration = get_keys_for_migration(bucket, keys_directory)
    [objects_to_be_archived, keys_for_migration]
  end

  def run_feed_migration_for_organization_with_login(feed_import, bucket, org_level_migration_status, skip_monitoring = false)
    is_success = true
    sftp_user_name = feed_import.sftp_user_name
    organization = feed_import.organization

    feed_import.get_source_options[:source_list].each do |source_info|
      status, info, local_file = DataImport::Status::SUCCESS, {}, ''
      objects_to_be_archived, keys_for_migration = get_objects_to_be_archived_and_keys_for_migration(bucket, sftp_user_name, source_info)

      if objects_to_be_archived.empty?
        feed_migrator_logger "Login : #{sftp_user_name} => No file present for migration"
        next
      end
      
      AccountMonitor::MonitoringSftp.clear_skip_feed_migration
      begin
        keys_for_migration.each do |key_object|
          key_file = File.join('', 'tmp', File.basename(key_object.key))
          File.open(key_file, 'w+b', encoding: CHARACTER_ENCODING) {|f| f.write(key_object.read.force_encoding(CHARACTER_ENCODING)) }
        end

        object = get_feed_object_from_objects_to_be_archived(objects_to_be_archived)
        local_file = get_local_file_name(sftp_user_name, object)
        File.open(local_file, 'w+b', encoding: CHARACTER_ENCODING) {|f| f.write(object.read.force_encoding(CHARACTER_ENCODING)) }
        feed_migrator_logger "Processing file: #{local_file} for #{sftp_user_name} (Time now : #{Time.now.utc.to_s})"
        # to fix the memory leak caused by other clients, just execute each feed with new process.
        result = Parallel.map([1], :in_processes => 1) do |_|
          ActiveRecord::Base.connection.reconnect!
          migrator = ChronusSftpFeed::Migrator.new(local_file, feed_import, source_info[:encrypted])

          unless migrator.run(skip_monitoring)
            AccountMonitor::MonitoringSftp.skip_feed_migration
          end

          migrator.info
        end
        info.merge!(result[0])
      rescue => error
        failure_message = get_failure_message_from_error(error)
        generate_general_error_notification(failure_message.presence || error)
        status = DataImport::Status::FAIL
        is_success = false
        info[:failure_message] = failure_message.presence || "Internal migration error"
      ensure
        unless AccountMonitor::MonitoringSftp.skip_feed_migration_status
          File.delete(local_file) if local_file.present? && File.exist?(local_file)
          if org_level_migration_status[sftp_user_name].nil?
            fill_org_level_migration_status_if_absent(org_level_migration_status, sftp_user_name, organization)
          end
          options = { :sftp_user_name => sftp_user_name, :organization => organization, :status => status, :info => info }
          update_main_and_skipped_migrations(org_level_migration_status, objects_to_be_archived, object, options)
        end
      end
    end
    is_success
  end

  def update_main_and_skipped_migrations(org_level_migration_status, objects_to_be_archived, object, options)
    objects_to_be_archived.each do |obj|
      if obj == object
        org_level_migration_status[options[:sftp_user_name]][:main_migration] << create_data_import_summary_and_delete_file(options[:organization], options[:status], obj, options[:info])
      else
        org_level_migration_status[options[:sftp_user_name]][:skipped_migrations] << create_data_import_summary_and_delete_file(options[:organization], DataImport::Status::SKIPPED, obj, {})
      end
    end
  end

  def create_data_import_summary_and_delete_file(organization, status,remote_object, info = {})
    temp_file = File.join('', 'tmp', File.basename(remote_object.key))
    File.open(temp_file, 'w+b', encoding: CHARACTER_ENCODING) {|f| f.write(remote_object.read.force_encoding(CHARACTER_ENCODING)) }
    data_import = create_data_import_summary(organization, status, File.open(temp_file), info)
    File.delete(temp_file)
    feed_migrator_logger "Deleting #{remote_object.key}"
    begin
      remote_object.delete
    rescue => error
      generate_general_error_notification(error)
      feed_migrator_logger "Deleting failed for source file '#{remote_object.key}'"
    end
    data_import
  end

  def create_data_import_summary(organization, status, file, info = {})
    begin
      error_file_name = info[:error_file_name]
      error_file = error_file_name.present? ? File.open(error_file_name) : nil
      data_import = organization.data_imports.create!(status: status, failure_message: info[:failure_message],
        created_count: info[:created_count], updated_count: info[:updated_count],
        suspended_count: info[:suspended_count], source_file: file, log_file: error_file)
      File.delete(error_file_name) if error_file_name.present?
      return data_import
    rescue => error
      generate_general_error_notification(error)
    end
  end

  def generate_general_error_notification(error)
    Airbrake.notify(error)
    feed_migrator_logger "ERROR: #{error}"
  end

  def send_email_notification(org_level_migration_status, is_success = true)
    initial_state = ActionMailer::Base.perform_deliveries
    ActionMailer::Base.perform_deliveries = true
    begin
      InternalMailer.data_feed_migration_status_notification_to_chronus(org_level_migration_status, is_success).deliver_now
    rescue => error
      feed_migrator_logger "Sending email failed: #{error}"
    end
    ActionMailer::Base.perform_deliveries = initial_state
  end

  def migrate(daily_feed, sftp_user_name, skip_monitoring = false)
    org_level_migration_status, is_success = {}, true
    begin
      bucket_name = set_credentials_and_get_bucket_name
      if bucket_name.present?
        bucket = establish_connection_and_get_bucket(bucket_name)
        active_feed_imports = FeedImportConfiguration.enabled.joins(:organization).where(programs: {active: true})
        feed_imports =
          if sftp_user_name.present?
            [active_feed_imports.find_by(sftp_user_name: sftp_user_name)].compact
          else
            daily_feed ? active_feed_imports.daily : active_feed_imports.weekly
          end
        feed_imports.each do |feed_import|
          is_success = run_feed_migration_for_organization_with_login(feed_import, bucket, org_level_migration_status, skip_monitoring) && is_success
        end
      end
    rescue => error
      generate_general_error_notification(error)
    ensure
      send_email_notification(org_level_migration_status,is_success)
    end
  end
end