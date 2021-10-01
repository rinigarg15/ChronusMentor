require_relative './../../../test_helper'

class CronTasks::FeedMigratorTest < ActiveSupport::TestCase

  def test_includes_feed_migrator
    CronTasks::FeedMigrator.new.respond_to?(:run_feed_migration_for_organization_with_login)
  end

  def test_perform
    CronTasks::FeedMigrator.any_instance.expects(:migrate).with(false, nil).once
    CronTasks::FeedMigrator.new.perform
  end

  def test_perform_when_daily
    delay_jobs do
      CronTasks::FeedMigrator.schedule(frequency: FeedImportConfiguration::Frequency::DAILY)
      CronTasks::FeedMigrator.any_instance.expects(:migrate).with(true, nil).once
      Delayed::Job.last.invoke_job
    end
  end
end