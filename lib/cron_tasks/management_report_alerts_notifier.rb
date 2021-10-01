module CronTasks
  class ManagementReportAlertsNotifier
    include Delayed::RecurringJob

    def perform
      Report::Alert.send_alert_mails
    end
  end
end