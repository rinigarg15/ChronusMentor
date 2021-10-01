module CronTasks
  class GroupActivitiesTracker
    include Delayed::RecurringJob

    def perform
      Group.track_inactivities
    end
  end
end