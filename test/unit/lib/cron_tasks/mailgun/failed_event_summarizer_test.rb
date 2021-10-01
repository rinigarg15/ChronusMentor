require_relative './../../../../test_helper'

class CronTasks::Mailgun::FailedEventSummarizerTest < ActiveSupport::TestCase

  def test_perform
    summarizer = mock
    summarizer.expects(:summarize).once
    ChronusMentorMailgun::FailedEventSummarizer.expects(:new).with(1).once.returns(summarizer)
    CronTasks::Mailgun::FailedEventSummarizer.new.perform
  end
end