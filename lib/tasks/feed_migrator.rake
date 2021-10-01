require "aws-sdk-v1"
require "activerecord-import"
require_relative './feed_migrator/feed_migrator'
include FeedMigrator

# Main migrator code
namespace :customer_feed do
  # To run for a specific client , pass CLIENT NAME
  # rake customer_feed:migrator CLIENT_NAME='coke'
  desc "Process the uploaded customer feed file and move it to archive"
  task(:migrator => :environment) do
    daily_feed = (ENV["DAILY_FEED"] == "true")
    skip_monitoring = (ENV["SKIP_MONITORING"] == "true")
    feed_migrator_logger "Starting customer feed migration (Time now : #{Time.now})"
    migrate(daily_feed, ENV["CLIENT_NAME"], skip_monitoring)
    feed_migrator_logger "DONE: customer feed migration (Time now : #{Time.now})" 
  end
end