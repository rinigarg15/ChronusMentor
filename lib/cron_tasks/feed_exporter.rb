module CronTasks
  class FeedExporter
    include Delayed::RecurringJob

    def perform
      is_daily = self.instance_variable_get(:@schedule_options).try(:[], :frequency) == ::FeedExporter::Frequency::DAILY
      feed_exporters = ::FeedExporter.send(is_daily ? :daily : :weekly)
      feed_exporters.each(&:export_and_upload)
    end
  end
end