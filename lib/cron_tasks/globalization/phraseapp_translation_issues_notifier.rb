# Validate translations from PhraseApp. This will look for interpolations({{}}, %{}) and html tag errors.
module CronTasks
  module Globalization
    class PhraseappTranslationIssuesNotifier
      include Delayed::RecurringJob

      def perform
        ::Globalization::PhraseappUtils.notify_corrupted_translations
      end
    end
  end
end