# Closes expired pending mentor_requests
module CronTasks
  class ExpiredMentorRequestsCloser
    include Delayed::RecurringJob

    def perform
      MentorRequest.notify_expired_mentor_requests
    end
  end
end