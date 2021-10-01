# Closes expired pending project_requests
module CronTasks
  class ExpiredProjectRequestsCloser
    include Delayed::RecurringJob

    def perform
      ProjectRequest.notify_expired_project_requests
    end
  end
end