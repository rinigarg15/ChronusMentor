module ChronusSftpFeed
  module Service
    class MigrationSplitter
      def run_updater(records, index, klass, options, config)
        options.merge!(records: records.flatten, start: ((index) * config.chunk_size + 1))
        updater = klass.new(config, options)
        updater.run
        config.push_log_streams
      end

      def run_suspension(users_or_members_scope, config, options = {})
        if options[:user_suspension]
          suspended_by = config.organization.admin_custom_term.term || "Administrator"
          admin_users_hash = config.mentor_admin.users.index_by(&:program_id)
        end
        BlockExecutor.execute_without_mails do
          DelayedEsDocument.skip_es_delta_indexing(auto_reindex: true) do
            users_or_members_scope.each do |user_or_member|
              begin
                user_or_member.suspend!(config.mentor_admin, "Suspended by #{config.custom_term_for_admin}", false) if options[:member_suspension]
                user_or_member.suspend_from_program!(admin_users_hash[user_or_member.program_id], "Suspended by #{suspended_by}", send_email: false) if options[:user_suspension]
              rescue => error
                ChronusSftpFeed::Migrator.logger "Suspension failed for #{options[:member_suspension] ? "member" : "user" } with ID: #{user_or_member.id}. Error: #{error.message}"
                # Check the User/Member variations in the message that is printed.
                config.log_error(["", "", "#{user_or_member.class} ID", user_or_member.id, "Suspension failed - #{error.message}"].join(CloudLogs::SPLITTER))
              end
            end
          end
          config.push_log_streams
        end
      end

      def run_reactivation(members_scope, config)
        BlockExecutor.execute_without_mails do
          DelayedEsDocument.skip_es_delta_indexing(auto_reindex: true) do
            members_scope.each do |member|
              begin
                member.reactivate!(config.mentor_admin, false)
              rescue => error
                ChronusSftpFeed::Migrator.logger "Reactivation failed for member with ID: #{member.id}. Error: #{error.message}"
                config.log_error(["", "", "Member ID", member.id, "Reactivation failed - #{error.message}"].join(CloudLogs::SPLITTER))
              end
            end
          end
        end
        config.push_log_streams
      end
    end
  end
end