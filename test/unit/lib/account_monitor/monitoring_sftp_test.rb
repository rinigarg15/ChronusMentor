require_relative './../../../test_helper.rb'

class MonitoringSftpTest < ActiveSupport::TestCase

  def test_sftp_monitor
    AccountMonitor::MonitoringSftp.stubs(:get_whitelisting_criteria).returns({ "sftp" => { "max_limit" => 20, "exclusions" => nil }})
    AccountMonitor::MonitoringSftp.stubs(:send_mail)
    assert_equal false, AccountMonitor::MonitoringSftp.sftp_monitor(30, 2)
    assert_equal true, AccountMonitor::MonitoringSftp.sftp_monitor(10, 2)
    AccountMonitor::MonitoringSftp.stubs(:get_whitelisting_criteria).returns({})
    assert_equal true, AccountMonitor::MonitoringSftp.sftp_monitor(10, 2)
    AccountMonitor::MonitoringSftp.stubs(:get_whitelisting_criteria).returns({ "sftp" => { "max_limit" => 20, "exclusions" => [{ "org_id" => 1, "max_limit" => 50 }]}})
    assert_equal false, AccountMonitor::MonitoringSftp.sftp_monitor(60, 1)
    assert_equal true, AccountMonitor::MonitoringSftp.sftp_monitor(45, 1)
  end

  def test_skip_migration_status
    File.stubs(:exist?).returns(true)
    File.stubs(:read).returns(1)
    assert_equal true, AccountMonitor::MonitoringSftp.skip_feed_migration_status
    File.stubs(:exist?).returns(false)
    assert_equal false, AccountMonitor::MonitoringSftp.skip_feed_migration_status
    File.stubs(:exist?).returns(true)
    File.stubs(:read).returns(0)
    assert_equal false, AccountMonitor::MonitoringSftp.skip_feed_migration_status
  end

  def test_skip_feed_migration
    File.stubs(:open).times(1)
    AccountMonitor::MonitoringSftp.skip_feed_migration
  end

  def test_clear_skip_feed_migration
    File.stubs(:open).times(1)
    AccountMonitor::MonitoringSftp.clear_skip_feed_migration
  end
end
