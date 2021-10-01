# Closes expired pending meeting_requests
module CronTasks
  class ExpiredMeetingRequestsCloser
    include Delayed::RecurringJob

    def perform
      MeetingRequest.notify_expired_meeting_requests
    end
  end
end