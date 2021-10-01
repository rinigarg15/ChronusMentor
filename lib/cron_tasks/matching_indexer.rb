module CronTasks
  class MatchingIndexer
    include Delayed::RecurringJob

    def perform
      Matching.perform_full_index_and_refresh
    end
  end
end