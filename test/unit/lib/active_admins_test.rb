require_relative './../../test_helper.rb'

class ActiveAdminsTest < ActiveSupport::TestCase
  include ActiveAdmins

  def test_get_admins_in_csv
    org_admins = Organization.first.members.where(:admin => true)
    csv = get_admins_in_csv(org_admins)
    assert_equal "ram@example.com", org_admins.collect(&:email).join
    assert_match /Freakin,Admin,ram@example.com/, csv
  end

  def test_pull_active_admins
    admins = Member.where(:admin => true)
    active_admins = pull_active_admins
    expected_user = active_admins.first
    assert_equal [:account_name, :org_name, :org_url, :program_name, :program_url, :first_name, :last_name, :email, :created_at], expected_user.keys
    assert_equal ["org_primary_account", "Primary Organization", "http://primary.#{DEFAULT_DOMAIN_NAME}/", "All", "http://primary.#{DEFAULT_DOMAIN_NAME}/p/albers/", "Freakin", "Admin", "ram@example.com"], expected_user.values[0..-2]

    expected_user = active_admins.second
    assert_equal [:account_name, :org_name, :org_url, :program_name, :program_url, :first_name, :last_name, :email, :created_at], expected_user.keys
    assert_equal ["org_primary_account", "Primary Organization", "http://primary.#{DEFAULT_DOMAIN_NAME}/", "Albers Mentor Program", "http://primary.#{DEFAULT_DOMAIN_NAME}/p/albers/", "Kal", "Raman", "userram@example.com"], expected_user.values[0..-2]
  end

  def test_pull_active_admins_in_csv
    active_admins_csv = "#{Rails.root.to_s}/tmp/active_admins.csv"
    pull_active_admins_in_csv(active_admins_csv)
    assert_match /Account Name,Organization,Organization URL,Programs,Last Active Program URL,First Name,Last Name,Email,Joined On/, File.read(active_admins_csv)
  end
end
