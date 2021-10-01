module CronTasks
  class FacilitationMessagesMailer
    include Delayed::RecurringJob

    def perform
      Notify.facilitation_messages
    end
  end
end