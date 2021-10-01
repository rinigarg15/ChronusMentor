module CronTasks
  class MatchConfigDiscrepancyCacheRefresher
    include Delayed::RecurringJob

    def perform
      MatchConfigDiscrepancyCache.refresh_top_discrepancies
    end
  end
end