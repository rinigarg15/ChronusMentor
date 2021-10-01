require_relative './../../../test_helper'

class ChronusAuthTest < ActiveSupport::TestCase

  def setup
    super
    @member = members(:ram)
    organization = @member.organization
    @chronus_auth = organization.chronus_auth
    @security_setting = organization.security_setting
  end

  def test_authenticate
    auth_obj = ProgramSpecificAuth.new(@chronus_auth, [@member.email, "monkey"])
    assert ChronusAuth.authenticate?(auth_obj, {})
    assert_nil auth_obj.status
    assert_equal @member.email, auth_obj.uid
    assert_equal @member, auth_obj.member

    auth_obj = ProgramSpecificAuth.new(@chronus_auth, [@member.email, "monkey1"])
    assert_false ChronusAuth.authenticate?(auth_obj, {})
    assert auth_obj.authentication_failure?
    assert_equal @member.email, auth_obj.uid
    assert_equal @member, auth_obj.member
  end

  def test_authenticate_invalid_email
    auth_obj = ProgramSpecificAuth.new(@chronus_auth, ["userram1@example.com", "monkey"])
    assert_nil ChronusAuth.authenticate?(auth_obj, {})
    assert auth_obj.authentication_failure?
    assert_equal "userram1@example.com", auth_obj.uid
    assert_nil auth_obj.member
  end

  def test_authenticate_when_login_attempts_enabled
    @security_setting.update_attributes!(maximum_login_attempts: 2)

    auth_obj = ProgramSpecificAuth.authenticate(@chronus_auth, @member.email, "monkey1")
    assert_equal 1, auth_obj.member.failed_login_attempts
    assert auth_obj.authentication_failure?

    assert_false ChronusAuth.authenticate?(auth_obj, {})
    assert_equal 2, auth_obj.member.failed_login_attempts
    assert auth_obj.authentication_failure?

    assert_emails 1 do
      auth_obj = ProgramSpecificAuth.authenticate(@chronus_auth, @member.email, "monkey1")
    end
    assert_equal 3, auth_obj.member.reload.failed_login_attempts
    assert auth_obj.account_blocked?
    assert_equal @member, auth_obj.member

    assert_no_emails do
      assert_false ChronusAuth.authenticate?(auth_obj, {})
    end
    assert_equal 3, auth_obj.member.reload.failed_login_attempts
    assert auth_obj.account_blocked?
    assert_equal @member, auth_obj.member
  end

  def test_password_expired
    auth_obj = nil

    @security_setting.update_attributes!(password_expiration_frequency: 2)
    admin_member = members(:f_admin)
    admin_member.update_attributes!(email: SUPERADMIN_EMAIL, password_updated_at: Time.now - 3.days)
    assert_no_emails do
      auth_obj = ProgramSpecificAuth.authenticate(@chronus_auth, admin_member.email, "monkey")
    end
    assert auth_obj.authenticated?
    assert auth_obj.member.reload.authenticated?(auth_obj.data[1])
    assert_equal admin_member, auth_obj.member
    @member.update_attributes!(password_updated_at: Time.now - 3.days)

    assert_emails 1 do
      auth_obj = ProgramSpecificAuth.new(@chronus_auth, [@member.email, "monkey"])
      assert ChronusAuth.authenticate?(auth_obj, {})
    end
    assert auth_obj.password_expired?
    assert auth_obj.member.reload.authenticated?(auth_obj.data[1])
    assert_equal @member, auth_obj.member
    assert_equal ProgramSpecificAuth::Status::PASSWORD_EXPIRED, auth_obj.status

    @security_setting.update_attributes!(password_expiration_frequency: 2)
    @member.update_attributes!(password_updated_at: Time.now)
    assert_no_emails do
      auth_obj = ProgramSpecificAuth.authenticate(@chronus_auth, @member.email, "monkey")
    end
    assert auth_obj.authenticated?
    assert auth_obj.member.reload.authenticated?(auth_obj.data[1])
    assert_equal @member, auth_obj.member
  end

  def test_authenticate_with_login_token
    member = members(:f_mentor)
    token_code = member.login_tokens.first.token_code
    auth_obj = ProgramSpecificAuth.new(@chronus_auth, [token_code, {token_login: true}])
    LoginToken.any_instance.expects(:expired?).returns(false)
    LoginToken.any_instance.expects(:mark_expired)
    assert ChronusAuth.authenticate?(auth_obj, {})
    assert_nil auth_obj.status
    assert_equal token_code, auth_obj.uid
    assert_equal member, auth_obj.member
  end

  def test_authenticate_with_invalid_login_token
    member = members(:f_mentor)
    auth_obj = ProgramSpecificAuth.new(@chronus_auth, ["invalid_token", {token_login: true}])
    assert_false ChronusAuth.authenticate?(auth_obj, {})
    assert_equal ProgramSpecificAuth::Status::INVALID_TOKEN, auth_obj.status
    assert_equal "invalid_token", auth_obj.uid
    assert_nil auth_obj.member
  end

  def test_authenticate_with_expired_login_token
    member = members(:f_mentor)
    login_token = member.login_tokens.first
    login_token.update_column(:last_used_at, Time.now)
    token_code = login_token.token_code
    auth_obj = ProgramSpecificAuth.new(@chronus_auth, [token_code, {token_login: true}])
    LoginToken.any_instance.expects(:expired?).returns(true)
    assert_false ChronusAuth.authenticate?(auth_obj, {})
    assert_equal ProgramSpecificAuth::Status::INVALID_TOKEN, auth_obj.status
    assert_equal token_code, auth_obj.uid
    assert_nil auth_obj.member
  end

  def test_authenticate_with_login_token_and_password_expired
    auth_obj = nil
    @security_setting.update_attributes!(password_expiration_frequency: 2)
    @member.update_attributes!(password_updated_at: Time.now - 3.days)
    login_token = create_login_token(member: @member)
    token_code = login_token.token_code
    auth_obj = ProgramSpecificAuth.new(@chronus_auth, [token_code, {token_login: true}])
    assert_no_emails do
      assert ChronusAuth.authenticate?(auth_obj, {})
    end
    assert_equal @member, auth_obj.member
    assert_nil auth_obj.status
  end
end