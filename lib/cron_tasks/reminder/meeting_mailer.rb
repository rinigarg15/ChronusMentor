# Sends reminders to attendees
module CronTasks
  module Reminder
    class MeetingMailer
      include Delayed::RecurringJob

      def perform
        MemberMeeting.send_meeting_reminders
      end
    end
  end
end