module CronTasks
  module Elasticsearch
    class DocumentCountChecker
      include Delayed::RecurringJob

      def perform
        models_with_index_name = ChronusElasticsearch.models_with_es.inject({}) do |models_with_index_name, model|
          models_with_index_name[model.name] = model.index_name
          models_with_index_name
        end
        EsDocumentCountChecker.check_and_fix_document_counts(models_with_index_name, count_only: false, for_deployment: false)
      end
    end
  end
end