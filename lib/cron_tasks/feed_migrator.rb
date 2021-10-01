require "aws-sdk-v1"
require "activerecord-import"
require_relative './../tasks/feed_migrator/feed_migrator'

module CronTasks
  class FeedMigrator
    include Delayed::RecurringJob
    include ::FeedMigrator

    def perform
      is_daily = self.instance_variable_get(:@schedule_options).try(:[], :frequency) == FeedImportConfiguration::Frequency::DAILY
      migrate(is_daily, nil)
    end
  end
end