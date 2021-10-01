# Auto-start circles on start_date
module CronTasks
  class CirclesAutoPublisher
    include Delayed::RecurringJob

    def perform
      Group.auto_publish_circles
    end
  end
end