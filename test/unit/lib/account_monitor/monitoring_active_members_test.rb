require_relative './../../../test_helper.rb'

class MonitoringActiveMembersTest < ActiveSupport::TestCase
  def test_get_org_ids_with_active_members_count
    assert_equal AccountMonitor::MonitoringActiveMembers.get_org_ids_with_active_members_count, orgs_with_active_members_count 
  end

  def test_get_active_organizations
    assert_equal AccountMonitor::MonitoringActiveMembers.get_active_organizations, Organization.active.pluck(:id)
  end

  def test_send_mail
    InternalMailer.any_instance.expects(:notify_account_monitoring_status_if_violated).times(1)
    AccountMonitor::MonitoringActiveMembers.send_mail("subject", "body")
  end

  def test_get_whitelisting_criteria
    assert_nil AccountMonitor::MonitoringActiveMembers.get_whitelisting_criteria
  end

  def test_get_whitelisted_orgs
    assert_equal AccountMonitor::MonitoringActiveMembers.get_whitelisted_orgs([{ "org_id" => 876, "max_limit" => 50000}]), { 876 => 50000 }
    assert_equal AccountMonitor::MonitoringActiveMembers.get_whitelisted_orgs(nil), {}
    assert_equal AccountMonitor::MonitoringActiveMembers.get_whitelisted_orgs([{ "org_id" => 876, "max_limit" => 50000 }, { "org_id" => 45, "max_limit" => 75000 }]), { 876 => 50000, 45 => 75000 }
  end

  def test_monitor
    AccountMonitor::MonitoringActiveMembers.stubs(:get_org_ids_with_active_members_count).returns({ 1 => 56, 2 => 14 })
    AccountMonitor::MonitoringActiveMembers.stubs(:get_whitelisting_criteria).returns({ "active_members" => { "max_limit" => 20, "exclusions" => nil }})
    AccountMonitor::MonitoringActiveMembers.stubs(:get_active_organizations).returns([1, 2])
    AccountMonitor::MonitoringActiveMembers.stubs(:send_mail).with("Organization with Org. Id.:[1] has more than SLA active members present atleast in one track", { 1 => {:active_members => 56, :limits => 20 }})
    AccountMonitor::MonitoringActiveMembers.active_member_monitor
  end

  private

  def orgs_with_active_members_count
    Member.joins(:users).where("users.state='#{User::Status::ACTIVE}'").distinct.group("members.organization_id").count
  end
end
