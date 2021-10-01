# Update the account names in product dashboard google spreadsheet
module CronTasks
  module ProductDashboard
    class AccountNamesUpdater
      include Delayed::RecurringJob

      def perform
        dashboard = ::ProductDashboard.new
        dashboard.update(account_names: true) if dashboard.allowed_for_env
      end
    end
  end
end