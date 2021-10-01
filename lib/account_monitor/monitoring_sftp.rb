# reload! && AccountMonitor::MonitoringSftp::skip_migration_check_failed
module AccountMonitor
  class MonitoringSftp
    extend AccountMonitor::AccountMonitorHelper
    SKIP_MIGRATION_CHECK_FILE = '/tmp/skip_migration_check_failed.txt'

    class << self

      def skip_feed_migration
        File.open(SKIP_MIGRATION_CHECK_FILE, 'w') { |f| f.puts "1" }
      end

      def clear_skip_feed_migration
        File.open(SKIP_MIGRATION_CHECK_FILE, 'w') { |f| f.puts "0" }
      end

      def skip_feed_migration_status
        if File.exist?(SKIP_MIGRATION_CHECK_FILE) && File.read(SKIP_MIGRATION_CHECK_FILE).to_i == 1
          return true  
        end
        return false
      end

      def sftp_monitor(modifying_record_count, organization_id)
        whitelisting_criteria = get_whitelisting_criteria

        return true if (whitelisting_criteria.blank? || whitelisting_criteria["sftp"].blank?)

        whitelisting_limits = whitelisting_criteria["sftp"]["max_limit"]
        whitelisted_orgs = get_whitelisted_orgs(whitelisting_criteria["sftp"]["exclusions"])

        if modifying_record_count > whitelisting_limits
          if whitelisted_orgs[organization_id].blank? || modifying_record_count > whitelisted_orgs[organization_id]
            send_mail("Skipped SFTP for Organization with Org. Id.:#{organization_id} Org. url:#{Organization.find(organization_id).url}, exceeds SFTP SLA", "modifying/creating records count: #{modifying_record_count}")
            return false
          end
        end
        return true
      end
    end
  end
end