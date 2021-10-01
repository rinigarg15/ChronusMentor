# Creates/renews Google Calendar API Notification Channel
module CronTasks
  class CalendarNotificationChannelEstablisher
    include Delayed::RecurringJob

    def perform
      current_time = Time.now

      BlockExecutor.iterate_fail_safe(SchedulingAccount.all) do |scheduling_account|
        last_notification_channel = scheduling_account.calendar_sync_notification_channels.last

        if last_notification_channel.blank? || (current_time + 2.days > last_notification_channel.expiration_time)
          Calendar::GoogleApi.new(scheduling_account.email).establish_new_notification_channel(scheduling_account)
        end
      end
    end
  end
end