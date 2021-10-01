module ChronusSftpFeed
  class Configuration
    attr_reader :organization, :mentor_admin, :custom_term_for_admin
    attr_reader :secondary_questions_map, :supplement_questions_map, :suspension_required, :allow_location_updates, :reactivate_suspended_users, :allow_manager_updates
    attr_reader :csv_options, :chunk_size
    attr_reader :data_map, :suspend_logic_map, :reactivate_logic_map
    attr_reader :custom_auth_config_ids, :login_identifier_header, :use_login_identifier
    attr_reader :import_file_name, :error_stream_name, :log_stream_name, :error_file_header
    attr_reader :allow_import_question, :import_question_text, :ignore_column_headers, :empty_row_data_for_value_match
    attr_reader :suspend_only_for_programs
    attr_reader :import_user_tags, :user_tags_header, :program_name_header
    attr_reader :prevent_name_override
    attr_reader :total_split_workers

    def initialize(file, feed_import)
      options = feed_import.get_config_options
      @organization = feed_import.organization
      @custom_auth_config_ids = @organization.get_and_cache_custom_auth_config_ids
      @mentor_admin = @organization.members.where(admin: true).first
      @custom_term_for_admin = @organization.admin_custom_term.term || "Administrator"

      # these questions will be skipped in first iteration during member update
      @secondary_questions_map = options[:secondary_questions_map] || ChronusSftpFeed::Constant::SECONDARY_QUESTIONS_MAP
      @suspension_required = options[:suspension_required] || ChronusSftpFeed::Constant::SUSPENSION_REQUIRED
      @suspend_only_for_programs = options[:suspend_program_roots] || ChronusSftpFeed::Constant::SUSPEND_ONLY_FOR_PROGRAMS

      # supplement questions map will be used when the data is dispersed across multiple columns
      @supplement_questions_map = options[:supplement_questions_map] || {}

      # should be used only if suspension column present in import file
      @suspend_logic_map = options[:suspend_logic_map] || {}

      # should be used only if reactivation column present in import file
      @reactivate_logic_map = options[:reactivate_logic_map] || {}

      if @custom_auth_config_ids.present?
        # header of the column to be imported as UUID for custom SSO(s)
        @login_identifier_header = options[:login_identifier_header]

        # if login_identifier_header(not email) has to be used for identifying member records
        @use_login_identifier = @login_identifier_header.present? && options[:use_login_identifier]
      end

      # to decide if we want to set the answer for imported_question_text for a member
      @allow_import_question  = options[:allow_import_question] || ChronusSftpFeed::Constant::ALLOW_IMPORT_QUESTION

      # this question text corresponds to the members imported/provisioned via feed
      @import_question_text = options[:import_question_text] || ChronusSftpFeed::Constant::IMPORT_QUESTION_TEXT

      # to ignore a column for the feed. ignore_column_headers must be an array.
      @ignore_column_headers = options[:ignore_column_headers] || []

      # empty the data present in the row for the given columns if the data matches with the given value.
      @empty_row_data_for_value_match = options[:empty_row_data_for_value_match] || {}

      # reactivate a suspended user if present in the csv
      @reactivate_suspended_users = options[:reactivate_suspended_users] || ChronusSftpFeed::Constant::REACTIVATE_SUSPENDED_USERS

      # csv and key mapping related settings
      @csv_options = ActiveSupport::HashWithIndifferentAccess.new(ChronusSftpFeed::Constant::CSV_OPTIONS).merge(options[:csv_options] || {})
      @chunk_size = @csv_options[:chunk_size]
      @allow_location_updates = options[:allow_location_updates] || ChronusSftpFeed::Constant::ALLOW_LOCATION_UPDATES
      @allow_manager_updates = options[:allow_manager_updates] || ChronusSftpFeed::Constant::ALLOW_MANAGER_UPDATES

      # tag import related settings
      @import_user_tags = options[:import_user_tags] || ChronusSftpFeed::Constant::IMPORT_USER_TAGS
      @user_tags_header = options[:user_tags_header] || ChronusSftpFeed::Constant::USER_TAGS_HEADER
      @program_name_header = options[:program_name_header] || ChronusSftpFeed::Constant::PROGRAM_NAME_HEADER

      # data related settings
      @data_map = populate_data_map_with_actual_choices(options[:data_map] || {})
      @prevent_name_override = options[:prevent_name_override] || ChronusSftpFeed::Constant::PREVENT_NAME_OVERRIDE

      # file related settings
      @import_file_name = file
      @error_stream_name = "#{organization.subdomain || organization.domain}_#{SecureRandom.hex(10)}_error"
      @log_stream_name = "#{organization.subdomain || organization.domain}_#{SecureRandom.hex(10)}_log"
      @error_file_header = ["row_number", "primary_key", "error_column_heading", "error_data", "error_message"]

      # Used to set max_workers in dj split.
      workers_count_file = "/usr/local/chronus/config/workers_count.yml"
      split_workers_per_server = File.exists?(workers_count_file) ? YAML.load_file(workers_count_file)["split"] : 4
      @total_split_workers = split_workers_per_server * MultipleServersUtils.get_servers_count(["primary_app", "secondary_app", "collapsed"])
    end

    def suspension_required?
      @suspension_required && @suspend_logic_map.empty?
    end

    def populate_data_map_with_actual_choices(data_map)
      data_map.each_pair do |question_text, answer_map|
        if answer_map.is_a?(Hash) && answer_map[:include_actual_choices]
          choices_map = {}
          question = @organization.profile_questions.joins(:translations).where("profile_question_translations.locale = ? AND profile_question_translations.question_text = ?", I18n.default_locale.to_s, question_text).first
          next if question.blank?
          question.default_choices.each { |choice| choices_map[choice] = choice }
          answer_map.merge!(choices_map)
        end
      end
      data_map
    end

    def reactivation_required?
      @reactivate_suspended_users && @reactivate_logic_map.empty?
    end

    def allow_location_updates?(header = [])
      @allow_location_updates && header.include?(@secondary_questions_map[ProfileQuestion::Type::LOCATION.to_s])
    end

    def allow_manager_updates?(header = [])
      @allow_manager_updates && (header.include?(@secondary_questions_map[ProfileQuestion::Type::MANAGER.to_s]) || @supplement_questions_map.keys.include?(@secondary_questions_map[ProfileQuestion::Type::MANAGER.to_s]))
    end

    def allow_user_tags_import?(header = [])
      @import_user_tags && header.include?(@user_tags_header) && header.include?(@program_name_header)
    end

    def primary_key_header
      self.use_login_identifier ? self.login_identifier_header : ChronusSftpFeed::Constant::EMAIL
    end

    def location_question(header = [])
      return nil unless self.allow_location_updates?(header)
      @organization.profile_questions.joins(:translations).where("profile_question_translations.locale = ? AND profile_question_translations.question_text = ? AND question_type = ?", I18n.default_locale.to_s, @secondary_questions_map[ProfileQuestion::Type::LOCATION.to_s], ProfileQuestion::Type::LOCATION).first
    end

    def manager_question(header = [])
      return nil unless self.allow_manager_updates?(header)
      @organization.profile_questions.joins(:translations).where("profile_question_translations.locale = ? AND profile_question_translations.question_text = ? AND question_type = ?", I18n.default_locale.to_s, @secondary_questions_map[ProfileQuestion::Type::MANAGER.to_s], ProfileQuestion::Type::MANAGER.to_s).first
    end

    def logger
      # While testing this method is stubbed to return TestLogs
      "CloudLogs"
    end

    def log_error(text)
      @error_stream ||= logger.constantize.new(APP_CONFIG[:chronus_mentor_log_group], self.error_stream_name)
      @error_stream.log(text)
    end

    def log_info(text)
      @log_stream ||= logger.constantize.new(APP_CONFIG[:chronus_mentor_log_group], self.log_stream_name)
      @log_stream.log(text)
    end

    def push_log_streams
      @error_stream.push_logs if @error_stream
      @log_stream.push_logs if @log_stream
    end

    def pull_log_stream(stream_name)
      if stream_name == "error"
        @error_stream ||= logger.constantize.new(APP_CONFIG[:chronus_mentor_log_group], self.error_stream_name)
        @error_stream.pull_logs
      else
        @log_stream ||= logger.constantize.new(APP_CONFIG[:chronus_mentor_log_group], self.log_stream_name)
        @log_stream.pull_logs
      end
    end

    def clear_log_streams
      # Set the streams to nil if CloudLogs are used.
      if logger == "CloudLogs"
        @error_stream = nil
        @log_stream = nil
      end
    end

    def delete_log_streams
      @error_stream.delete_log_stream if @error_stream
      @log_stream.delete_log_stream if @log_stream
    end
  end
end