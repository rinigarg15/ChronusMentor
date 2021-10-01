module ChronusSftpFeed
  class Migrator
    include ChronusSftpFeed::ModifiedRecords
    attr_reader :config, :info

    def self.logger(object)
      puts "#{object}"
      Delayed::Worker.logger.info "SFTP log - #{object}"
    end

    def initialize(file, feed_import, encrypted = false)
      if feed_import.preprocessor.present?
        pre_processor = "ChronusSftpFeed::Preprocessor::#{feed_import.preprocessor}".constantize
        file = pre_processor.pre_process(file,
          organization_name: feed_import.organization.subdomain,
          is_encrypted: encrypted
        )
      end
      @config = ChronusSftpFeed::Configuration.new(file, feed_import)
      @info = { suspended_count: 0 }
      @config.log_error(@config.error_file_header.join(CloudLogs::SPLITTER))
      @config.push_log_streams
    end

    def run(skip_monitoring = false)
      @start_time = Time.now
      csv_options = @config.csv_options.symbolize_keys
      @total_chunks = SmarterCSV.process(@config.import_file_name, csv_options)
      # With key_mapping options smarter csv will convert the mapped keys into symbolic keys
      # So, explicitly stringfy the keys using below code based on whether key_mapping option is present.
      @total_chunks.each { |chunk| chunk.each { |record_hash| record_hash.stringify_keys! } } if csv_options[:key_mapping].present?
      @header = @total_chunks[0][0].keys
      @header -= @config.ignore_column_headers if @config.ignore_column_headers.present?
      @modified_chunks = get_modified_chunks(@config, @total_chunks)

      ChronusSftpFeed::Migrator.logger "Total(approx): #{@total_chunks.size * csv_options[:chunk_size]} Modified(approx): #{@modified_chunks.size * csv_options[:chunk_size]} \n" 

      return false if !skip_monitoring && !AccountMonitor::MonitoringSftp.sftp_monitor(@modified_chunks.size * csv_options[:chunk_size], @config.organization.id)

      @config.clear_log_streams # Clear streams before dj split as Log streams has a IO and Proc which are not compatible with dj serialization.
      find_duplicates
      perform_migrations
      perform_location_migrations if @config.allow_location_updates?(@header)
      perform_suspension if @config.suspension_required?
      perform_reactivation if @config.reactivation_required?
      profile_question_ids_to_clean = update_feed_import_configuration
      #Running SFTP feed and Import CSV users parallely might create duplicate other choice records. So cleaning other choice records post imports
      QuestionChoice.cleanup_duplicate_other_choices(profile_question_ids_to_clean)
      build_log_info
      return true
    end

    private

    def update_feed_import_configuration
      organization = @config.organization
      feed_import = organization.feed_import_configuration
      options = feed_import.get_config_options
      all_csv_available_question_texts = @header + (options[:secondary_questions_map].try(:values) || [])
      options[:imported_profile_question_texts] = (organization.profile_questions_with_email_and_name.includes(:translations).map(&:question_text) & all_csv_available_question_texts)
      feed_import.set_config_options!(options)
      return organization.profile_questions_with_email_and_name.where(question_text: options[:imported_profile_question_texts], allow_other_option: true, question_type: ProfileQuestion::Type.choice_based_types).pluck(:id)
    end

    def perform_migrations
      klasses = [ChronusSftpFeed::Service::MemberUpdater]
      klasses << ChronusSftpFeed::Service::ManagerUpdater if @config.allow_manager_updates?(@header)

      klasses.each do |klass|
        start_time = Time.now
        ChronusSftpFeed::Migrator.logger "Starting #{klass.name} import #{start_time}\n"
        options = {
          header: @header,
          duplicate_keys: @duplicate_keys,
        }
        DjSplit.new(queue_options: {queue: "split"}, split_options: {size: 1, by: 2, with_index: 3}).enqueue(ChronusSftpFeed::Service::MigrationSplitter.new(), "run_updater", @modified_chunks, 0, klass, options, @config)
        ChronusSftpFeed::Migrator.logger "Finished #{klass.name} import #{Time.now}\n"
        ChronusSftpFeed::Migrator.logger "Total Time Taken: #{((Time.now - start_time)/60).round(2)} minutes"
      end
    end

    def perform_location_migrations
      start_time = Time.now
      ChronusSftpFeed::Migrator.logger "Starting Location caching #{start_time}\n"
      location_map = ChronusSftpFeed::Service::LocationUpdater.fetch_location_map(@config, @modified_chunks)
      ChronusSftpFeed::Migrator.logger "Finished Location caching in: #{((Time.now - start_time)/60).round(2)} minutes\n"

      start_time = Time.now
      options = {
        header: @header,
        duplicate_keys: @duplicate_keys,
        location_map: location_map
      }
      # No parallelization till max worker implemented in splitter due to Deadlocks.  
      ChronusSftpFeed::Service::MigrationSplitter.new.run_updater(@modified_chunks, 0, ChronusSftpFeed::Service::LocationUpdater, options, @config)
      @config.clear_log_streams
      ChronusSftpFeed::Migrator.logger "Finished Location update in: #{((Time.now - start_time)/60).round(2)} minutes\n"
    end

    def find_duplicates
      ChronusSftpFeed::Migrator.logger "Finding duplicates emails..."
      @primary_keys = @total_chunks.map { |chunk| chunk.map { |record| get_primary_key(record) } }.flatten
      grouped_keys = @primary_keys.group_by { |e| e }
      invalid_primary_keys = grouped_keys.select { |k, v| v.size > 1 }
      @duplicate_keys = invalid_primary_keys.keys
      @info[:no_primary_key_count] = grouped_keys[""].present? ? grouped_keys[""].size : 0
      ChronusSftpFeed::Migrator.logger "Records without primary key: #{@info[:no_primary_key_count]}"
      ChronusSftpFeed::Migrator.logger "Duplicate keys count: #{(@duplicate_keys - [""]).size}"
      @primary_keys.select! { |key| key.present? }
    end

    def perform_reactivation
      members_scope = get_members_scope.suspended
      return if members_scope.size == 0

      start_time = Time.now
      ChronusSftpFeed::Migrator.logger "Starting member reactivation #{start_time}\n"
      ChronusSftpFeed::Migrator.logger "Total members to reactivate: #{members_scope.size}"
      DjSplit.new(queue_options: {queue: "split", max_workers: (@config.total_split_workers * 50 / 100)}, split_options: {size: 100, by: 2 }).enqueue(ChronusSftpFeed::Service::MigrationSplitter.new(), "run_reactivation", members_scope, @config)
      ChronusSftpFeed::Migrator.logger "Finished member reactivation in: #{((Time.now - start_time)/60).round(2)} minutes\n"
    end

    def perform_suspension
      @config.suspend_only_for_programs.present? ? perform_user_suspension_for_programs : perform_member_suspensions
    end

    def perform_member_suspensions
      member_ids = get_members_scope.pluck(:id)
      members_scope = @config.organization.members.non_suspended.where.not(admin: true).where.not(id: member_ids)
      return if members_scope.size == 0
      @info[:suspended_count] = members_scope.size
      start_time = Time.now
      ChronusSftpFeed::Migrator.logger "Starting member suspension #{start_time}\n"
      ChronusSftpFeed::Migrator.logger "Total members to suspend: #{members_scope.size}"
      DjSplit.new(queue_options: {queue: "split", max_workers: (@config.total_split_workers * 50 / 100)}, split_options: {size: 50, by: 2 }).enqueue(ChronusSftpFeed::Service::MigrationSplitter.new(), "run_suspension", members_scope, @config, member_suspension: true)  
      ChronusSftpFeed::Migrator.logger "Finished member suspension in: #{((Time.now - start_time)/60).round(2)} minutes\n"
    end

    def perform_user_suspension_for_programs
      suspend_program_roots = @config.suspend_only_for_programs
      program_ids = @config.organization.programs.where(root: suspend_program_roots).pluck(:id)
      members_not_to_suspend_ids = get_members_scope.pluck(:id)
      members_not_to_suspend_ids << @config.mentor_admin.id
      user_scope = User.active_or_pending.where(program_id: program_ids).where("member_id NOT IN (?)", members_not_to_suspend_ids)
      users_to_suspend = user_scope.size
      @info[:suspended_count] = users_to_suspend
      return if users_to_suspend == 0
      start_time = Time.now
      ChronusSftpFeed::Migrator.logger "Starting user suspension #{start_time}\n"
      ChronusSftpFeed::Migrator.logger "Total users to suspend: #{user_scope.size}"
      DjSplit.new(queue_options: {queue: "split", max_workers: (@config.total_split_workers * 50 / 100)}, split_options: {size: 50, by: 2 }).enqueue(ChronusSftpFeed::Service::MigrationSplitter.new(), "run_suspension", user_scope, @config, user_suspension: true)
      DelayedEsDocument.delayed_bulk_update_es_documents(User, users_scope.collect(&:id))
      ChronusSftpFeed::Migrator.logger "Finished user suspension in: #{((Time.now - start_time)/60).round(2)} minutes\n"
    end


    def build_log_info
      ChronusSftpFeed::Migrator.logger "Finished import"
      ChronusSftpFeed::Migrator.logger "Total Time Taken: #{((Time.now - @start_time)/60).round(2)} minutes"
      @error_data = @config.pull_log_stream("error").map { |row| row.split(CloudLogs::SPLITTER) }
      fetch_update_logs
      @info[:invalid_rows_data] = @error_data.drop(1)
      @info[:duplicate_keys] = @duplicate_keys
      # suspended_count = count_for_suspension - count_failing_suspension. Error array's last column has a message with Suspension failed for if failed
      @info[:suspended_count] = @info[:suspended_count].to_i - @error_data.count {|error| error.last.include?("Suspension failed for") }
      @config.delete_log_streams
      ChronusSftpFeed::Migrator.logger "#{@info}"
    end

    def log_memory(text)
      ChronusSftpFeed::Migrator.logger "Process: #{Process.pid},#{[text, 'RAM USAGE: ' + `pmap #{Process.pid} | tail -1`[10,40].strip]}, Time: #{Time.now}\n"
    end

    def fetch_update_logs
      logger_data = @config.pull_log_stream("log").map { |row| row.split(CloudLogs::SPLITTER) }
      uniq_record_logs = logger_data.group_by { |x| x[0] }
      created_count = 0
      updated_count = 0
      suspended_count = 0
      uniq_record_logs.each do |record_index, values|
        array = values.map{|x| x[1].to_i}
        if array.include?(ChronusSftpFeed::UpdateType::CREATED)
          created_count += 1
        elsif array.include?(ChronusSftpFeed::UpdateType::SUSPENDED)
          suspended_count += 1
        elsif array.include?(ChronusSftpFeed::UpdateType::UPDATED)
          updated_count += 1
        end
      end
      @info[:created_count] = created_count
      @info[:updated_count] = updated_count
      @info[:suspended_count] = suspended_count unless @config.suspend_logic_map.empty?

      @info[:error_file_name] = nil
      if @error_data.size > 1
        error_file_name = "#{Rails.root}/tmp/#{Time.now.to_i}_#{@config.organization.subdomain || @config.organization.domain}_import_error_log.csv"
        CSV.open(error_file_name, "w") do |csv|
          @error_data.each do |row|
            csv << row
          end
        end
        @info[:error_file_name] = error_file_name
      end
    end

    def get_primary_key(record)
      primary_key = record[@config.primary_key_header]
      @config.use_login_identifier ? primary_key : primary_key.try(:downcase)
    end

    def get_members_scope
      members_scope = @config.organization.members
      if @config.use_login_identifier
        member_ids = LoginIdentifier.where(auth_config_id: @config.custom_auth_config_ids, identifier: @primary_keys).pluck(:member_id)
        members_scope.where(id: member_ids)
      else
        members_scope.where(email: @primary_keys)
      end
    end
  end
end