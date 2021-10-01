# Sends reminders for the meeting requests awaiting response
module CronTasks
  module Reminder
    class MeetingRequestMailer
      include Delayed::RecurringJob

      def perform
        MeetingRequest.send_meeting_request_reminders
      end
    end
  end
end