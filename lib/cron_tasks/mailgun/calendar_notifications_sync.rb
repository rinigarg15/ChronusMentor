module CronTasks
  module Mailgun
    class CalendarNotificationsSync
      include Delayed::RecurringJob

      def perform
        Calendar::PullNotification.new.update_meetings_and_program_events_with_calendars
      end
    end
  end
end