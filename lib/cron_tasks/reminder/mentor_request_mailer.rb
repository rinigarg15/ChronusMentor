# Sends reminders for the mentor requests awaiting response
module CronTasks
  module Reminder
    class MentorRequestMailer
      include Delayed::RecurringJob

      def perform
        MentorRequest.send_mentor_request_reminders
      end
    end
  end
end