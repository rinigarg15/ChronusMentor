require_relative './../../test_helper.rb'

class EmailFormatCheckTest < ActiveSupport::TestCase
  include EmailFormatCheck

  def test_email_format_check
    security_setting = programs(:org_primary).security_setting
    member = programs(:org_primary).members.last
    security_setting.update_attribute(:email_domain, " test.com, gmail.com    ")
    member.email = "test@raid.com"
    member.validate_email_format(true, member.email, security_setting)
    assert member.errors[:email].present?
  end

  def test_is_allowed_domain
    security_setting = programs(:org_primary).security_setting
    security_setting.update_attribute(:email_domain, " test.com, gmail.com    ")
    
    assert_false is_allowed_domain?("test@raid.com", security_setting)
    assert is_allowed_domain?("test@test.com", security_setting)
    assert is_allowed_domain?("test@gmail.com", security_setting)
  end
end