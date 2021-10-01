# Sends reminders for the project requests awaiting response
module CronTasks
  module Reminder
    class ProjectRequestMailer
      include Delayed::RecurringJob

      def perform
        ProjectRequest.send_project_request_reminders
      end
    end
  end
end