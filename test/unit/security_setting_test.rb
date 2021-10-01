require_relative './../test_helper.rb'

class SecuritySettingTest < ActiveSupport::TestCase
  def test_invalid_security_setting
    new_setting = SecuritySetting.new(:maximum_login_attempts => "-2", :auto_reactivate_account => "-2.0")
    assert_false new_setting.valid?

    assert_equal(["can't be blank"], new_setting.errors[:program_id])
    assert_equal([], new_setting.errors[:allowed_ips])
    assert_equal(["must be greater than or equal to 0"], new_setting.errors[:maximum_login_attempts])
    assert_equal(["must be greater than or equal to 0"], new_setting.errors[:auto_reactivate_account])
  end

  def test_allowed_ip_values
    assert setting.valid?
    assert_equal [], setting.allowed_ip_values
  end

  def test_allowed_ip_values_with_valid_ip
    setting.allowed_ips = "127.0.0.1"
    setting.save
    assert setting.valid?
    assert_equal [IPAddr.new('127.0.0.1')], setting.allowed_ip_values
    assert_equal([], setting.errors[:allowed_ips])
  end

  def test_allowed_ip_values_with_ip_range
    setting.allowed_ips = '192.168.1.0:192.168.1.222'
    setting.save
    assert setting.valid?, 'ranged allowed_ips should be valid'
    assert_equal [IPAddr.new('192.168.1.0')..IPAddr.new('192.168.1.222')], setting.allowed_ip_values
    assert_equal([], setting.errors[:allowed_ips])
  end

  def test_allowed_ip_values_with_reverse_ip_range
    setting.allowed_ips = '192.168.1.222:192.168.1.0'
    setting.save
    assert_false setting.valid?, 'reverse ranged allowed_ips should be invalid'
    assert_equal(['contains invalid address value'], setting.errors[:allowed_ips])
  end

  def test_allowed_ip_values_with_equal_range
    setting.allowed_ips = '192.168.1.0:192.168.1.0'
    setting.save
    assert setting.valid?, 'range with equal limits should be valid'
    assert_equal([], setting.errors[:allowed_ips])
  end

  def test_allowed_ip_values_with_one_invalid_ip
    setting.allowed_ips = "127.0.0.1, 256.0.0.1"
    setting.save
    assert_false setting.valid?
    assert_equal(['contains invalid address value'], setting.errors[:allowed_ips])
    assert_equal [], setting.reload.allowed_ip_values
  end

  def test_allowed_ip_values_with_ip_and_invalid_dns
    setting.allowed_ips = "127.0.0.1, test"
    setting.save
    assert_false setting.valid?
    assert_equal(['contains invalid address value'], setting.errors[:allowed_ips])
    assert_equal_unordered [], setting.reload.allowed_ip_values
  end

  def test_allowed_ip_values_with_duplicates
    setting.allowed_ips = "127.0.0.1, 8.8.8.8 , 8.8.8.8, 127.0.0.1"
    setting.save
    assert setting.valid?
    assert_equal_unordered [IPAddr.new('127.0.0.1'), IPAddr.new('8.8.8.8')], setting.reload.allowed_ip_values
  end

  def test_allow_ip
    # with blank ips
    assert setting.allow_ip?('66.242.231.44')
    assert setting.allow_ip?('127.0.0.1')
    assert setting.allow_ip?('192.168.1.1')
    assert setting.allow_ip?('192.168.1.11')
    assert setting.allow_ip?('192.168.1.22')
    assert setting.allow_ip?('127.0.0.2')
    assert setting.allow_ip?('8.8.8.8')
    assert setting.allow_ip?('192.168.1.0')
    assert setting.allow_ip?('192.168.1.23')

    setting.allowed_ips = "127.0.0.1,192.168.1.1:192.168.1.22"
    setting.save

    assert setting.allow_ip?('127.0.0.1')
    assert setting.allow_ip?('192.168.1.1')
    assert setting.allow_ip?('192.168.1.11')
    assert setting.allow_ip?('192.168.1.22')

    assert_false setting.allow_ip?('127.0.0.2')
    assert_false setting.allow_ip?('8.8.8.8')
    assert_false setting.allow_ip?('192.168.1.0')
    assert_false setting.allow_ip?('192.168.1.23')
  end

  def test_deny_ip
    # with blank ips
    assert_false setting.deny_ip?('127.0.0.1')
    assert_false setting.deny_ip?('192.168.1.1')
    assert_false setting.deny_ip?('192.168.1.11')
    assert_false setting.deny_ip?('192.168.1.22')
    assert_false setting.deny_ip?('127.0.0.2')
    assert_false setting.deny_ip?('8.8.8.8')
    assert_false setting.deny_ip?('192.168.1.0')
    assert_false setting.deny_ip?('192.168.1.23')

    setting.allowed_ips = "127.0.0.1,192.168.1.1:192.168.1.22"
    setting.save

    assert_false setting.deny_ip?('127.0.0.1')
    assert_false setting.deny_ip?('192.168.1.1')
    assert_false setting.deny_ip?('192.168.1.11')
    assert_false setting.deny_ip?('192.168.1.22')

    assert setting.deny_ip?('127.0.0.2')
    assert setting.deny_ip?('8.8.8.8')
    assert setting.deny_ip?('192.168.1.0')
    assert setting.deny_ip?('192.168.1.23')
  end

  def test_ip_address_separator
    assert_equal ',', SecuritySetting.ip_address_separator
  end

  def test_ip_ranges_separator
    assert_equal ':', SecuritySetting.ip_ranges_separator
  end


private
  def setting
    @setting ||= programs(:org_primary).security_setting
  end
end
