require_relative './../../test_helper'

class EmailMonitorTest < ActiveSupport::TestCase

  def test_send_email
    Delayed::Worker.stubs(:delay_jobs).returns(true)
    EmailMonitor.any_instance.expects(:email_monitoring_enabled?).returns(true).once
    EmailMonitor.any_instance.expects(:send_test_email).once
    assert_difference("Delayed::Job.count") { EmailMonitor.new.send_email }
    assert_time_is_equal_with_delta EmailMonitor::DEFAULT_WAIT_TIME.from_now, Delayed::Job.last.run_at
  end

  def test_send_email_when_email_monitoring_disabled
    EmailMonitor.any_instance.expects(:send_test_email).never
    assert_no_difference("Delayed::Job.count") { EmailMonitor.new.send_email }
  end

  def test_verify_email
    x = mock
    y = mock

    x.stubs(:text).returns("message")
    y.stubs(:data).returns(x)
    EmailMonitor.any_instance.expects(:retry_interval_in_seconds).returns(1).times(3)
    EmailMonitor.any_instance.stubs(:check_email).raises(Net::IMAP::ByeResponseError, y).then.raises(Net::IMAP::BadResponseError, y).then.raises(Net::IMAP::NoResponseError, y).then.returns(true)

    t1 = Time.now
    EmailMonitor.new.verify_email
    assert_operator (Time.now - t1), :>=, 3.seconds
  end

  def test_verify_email_failure
    email_monitor = EmailMonitor.new
    gmail_mock = mock
    inbox_mock = mock

    gmail_mock.expects(:inbox).once.returns(inbox_mock)
    gmail_mock.expects(:deliver).once
    inbox_mock.expects(:emails).once.with(:unread, from: EmailMonitor::FROM_EMAIL_ID, subject: "[#{Rails.env}] Email Monitoring via DJ unique_identifier: #{email_monitor.unique_identifier}").returns([])
    Gmail.expects(:new).returns(gmail_mock)
    email_monitor.verify_email
  end
end