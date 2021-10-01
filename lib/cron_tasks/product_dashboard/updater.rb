# Update the data in product dashboard google spreadsheet
module CronTasks
  module ProductDashboard
    class Updater
      include Delayed::RecurringJob

      def perform
        dashboard = ::ProductDashboard.new
        dashboard.update if dashboard.allowed_for_env
      end
    end
  end
end