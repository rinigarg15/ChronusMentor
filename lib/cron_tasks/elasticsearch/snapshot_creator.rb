# Takes manual snapshot of AWS ES domain
module CronTasks
  module Elasticsearch
    class SnapshotCreator
      include Delayed::RecurringJob

      def perform
        EsSnapshot.create
      end
    end
  end
end