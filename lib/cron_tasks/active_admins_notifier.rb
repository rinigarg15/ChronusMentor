module CronTasks
  class ActiveAdminsNotifier
    include ActiveAdmins
    include Delayed::RecurringJob

    def perform
      return unless APP_CONFIG[:notify_active_admins_to_cs]

      active_admins_csv = "#{Rails.root}/tmp/active_admins.csv"
      pull_active_admins_in_csv(active_admins_csv)
      InternalMailer.notify_active_admins(active_admins_csv).deliver_now
    end
  end
end