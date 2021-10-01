# Sends reminders to attendees
module CronTasks
  module Reminder
    class ProgramEventMailer
      include Delayed::RecurringJob

      def perform
        ProgramEvent.send_program_event_reminders
      end
    end
  end
end