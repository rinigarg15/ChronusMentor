# To notify when the number of active members in an organization crosses SLA
module CronTasks
  class ActiveMembersMonitor
    include Delayed::RecurringJob

    def perform
      AccountMonitor::MonitoringActiveMembers.active_member_monitor
    end
  end
end