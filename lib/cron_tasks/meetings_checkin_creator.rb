# Create checkins for the meetings
module CronTasks
  class MeetingsCheckinCreator
    include Delayed::RecurringJob

    def perform
      GroupCheckin.meetings_checkin_creation
    end
  end
end