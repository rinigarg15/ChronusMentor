module CronTasks
  class GroupsExpirer
    include Delayed::RecurringJob

    def perform
      Group.terminate_expired_connections
    end
  end
end