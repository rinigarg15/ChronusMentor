require_relative './../../../test_helper'

class CronTasks::FeedExporterTest < ActiveSupport::TestCase

  def test_perform
    feed_exporter = mock
    feed_exporter.expects(:export_and_upload).once
    FeedExporter.expects(:weekly).once.returns([feed_exporter])
    CronTasks::FeedExporter.new.perform
  end

  def test_perform_when_daily
    delay_jobs do
      CronTasks::FeedExporter.schedule(frequency: FeedExporter::Frequency::DAILY)
      feed_exporter = mock
      feed_exporter.expects(:export_and_upload).once
      FeedExporter.expects(:daily).once.returns([feed_exporter])
      Delayed::Job.last.invoke_job
    end
  end
end