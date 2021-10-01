# Fetch and mail keys which are in english but are not present in some other locale
module CronTasks
  module Globalization
    class UntranslatedStringsNotifier
      include Delayed::RecurringJob

      def perform
        ::Globalization::PhraseappUtils.notify_untranslated_strings
      end
    end
  end
end