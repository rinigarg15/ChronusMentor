# Notify if current server is not the main server (Detect multiple servers running)
module CronTasks
  class BackupServerDetector
    include Delayed::RecurringJob

    def perform
      MultipleServersUtils.detect_multiple_servers_running
    end
  end
end