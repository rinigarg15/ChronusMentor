module CronTasks
  class DigestV2Trigger
    include Delayed::RecurringJob

    def perform
      DigestV2Utils::Trigger.new.start
    end
  end
end