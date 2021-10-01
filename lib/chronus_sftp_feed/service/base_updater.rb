module ChronusSftpFeed
  module Service
    class BaseUpdater
      def initialize(config, options = {})
        @config = config
        @organization = @config.organization
        @records = options[:records] || []
        @start = options[:start].to_i
        @header = options[:header]
        @duplicate_keys = options[:duplicate_keys]
        @question_text = options[:question_text]
        @reactivate_suspended_users = options[:reactivate_suspended_users]
        @error_data = []
        @logger_data = []
      end

      def run
        BlockExecutor.execute_without_mails do
          DelayedEsDocument.skip_es_delta_indexing(auto_reindex: true) do
            ActiveRecord::Base.transaction do
              @records.each_with_index do |record, i|
                reset_record_logger
                update_record(record, @start + i)
              end
            end
          end
          build_logs
        end
      end

      private

      def build_logs
        if @error_data.present?
          @error_data.each do |error|
            @config.log_error(error.join(CloudLogs::SPLITTER))
          end
        end
        if @logger_data.present?
          @logger_data.each do |data|
            @config.log_info(data.join(CloudLogs::SPLITTER))
          end
        end
      end

      def reset_record_logger
        @created, @suspended, @updated = [false, false, false]
      end

      def get_mapped_value(record, key)
        data = record[key]
        if @config.data_map.present?
          if @config.data_map.keys.include?(key)
            data = @config.data_map[key][data]
          elsif @config.data_map.keys.include?(data)
            data = @config.data_map[data]
          end
        end
        data
      end

      def save_record!(object, force_save = false)
        if object.changed? || force_save
          object.save!
          @updated ||= true
        end
      end

      def get_primary_key(record)
        primary_key = record[@config.primary_key_header]
        @config.use_login_identifier ? primary_key : primary_key.try(:downcase)
      end

      def push_logger_data(member, record_index)
        return unless @created || @updated || @suspended

        if @created
          @logger_data << [record_index, ChronusSftpFeed::UpdateType::CREATED, member.email]
        elsif @suspended
          @logger_data << [record_index, ChronusSftpFeed::UpdateType::SUSPENDED, member.email]
        elsif @updated
          @logger_data << [record_index, ChronusSftpFeed::UpdateType::UPDATED, member.email]
        end
      end

      def initialize_members_map
        primary_keys = @records.map { |record| get_primary_key(record) }
        members_scope = @organization.members
        members_scope =
          if @config.use_login_identifier
            login_identifier_map = LoginIdentifier.where(auth_config_id: @config.custom_auth_config_ids, identifier: primary_keys).pluck(:member_id, :identifier).to_h
            members_scope.where(id: login_identifier_map.keys)
          else
            members_scope.where(email: primary_keys)
          end
        members_scope = members_scope.includes(:login_identifiers) if @config.login_identifier_header.present?

        @members_map = {}
        members_scope.find_each do |member|
          key = @config.use_login_identifier ? login_identifier_map[member.id] : member[:email].downcase
          @members_map[key] = member
        end
        members_scope
      end
    end
  end
end