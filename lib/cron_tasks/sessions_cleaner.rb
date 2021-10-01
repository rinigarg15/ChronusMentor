module CronTasks
  class SessionsCleaner
    include Delayed::RecurringJob

    def perform
      session_store = ActiveRecord::SessionStore::Session
      session_store.where("updated_at < ?", SESSION_DATA_CLEARANCE_PERIOD.ago).delete_all
    end
  end
end