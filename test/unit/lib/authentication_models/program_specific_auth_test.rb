require_relative './../../../test_helper'

class ProgramSpecificAuthTest < ActiveSupport::TestCase

  def test_initialize
    args = ["email", "password"]
    auth_config = programs(:org_primary).chronus_auth

    auth_obj = ProgramSpecificAuth.new(auth_config, args)
    assert_equal auth_config, auth_obj.auth_config
    assert_equal args, auth_obj.data
  end

  def test_authentication_status
    status_method_map = {
      ProgramSpecificAuth::Status::AUTHENTICATION_SUCCESS => :authenticated?,
      ProgramSpecificAuth::Status::NO_USER_EXISTENCE => :no_user_existence?,
      ProgramSpecificAuth::Status::AUTHENTICATION_FAILURE => :authentication_failure?,
      ProgramSpecificAuth::Status::ACCOUNT_BLOCKED => :account_blocked?,
      ProgramSpecificAuth::Status::PASSWORD_EXPIRED => :password_expired?,
      ProgramSpecificAuth::Status::MEMBER_SUSPENSION => :member_suspended?,
      ProgramSpecificAuth::Status::PERMISSION_DENIED => :permission_denied?,
       ProgramSpecificAuth::Status::INVALID_TOKEN => :invalid_token?
    }
    status_methods = status_method_map.values

    auth_obj = ProgramSpecificAuth.new(nil, nil)
    status_method_map.each do |status, status_method|
      auth_obj.status = status
      assert auth_obj.send(status_method)

      other_status_methods = status_methods - [status_method]
      other_status_methods.each do |other_status_method|
        assert_false auth_obj.send(other_status_method)
      end
    end
  end

  def test_deny_permission
    auth_obj = ProgramSpecificAuth.new(nil, nil)
    assert_false auth_obj.deny_permission?

    auth_obj.has_data_validation = true
    auth_obj.is_data_valid = false
    assert auth_obj.deny_permission?

    auth_obj.is_data_valid = true
    assert_false auth_obj.deny_permission?
  end

  def test_is_uid_email
    auth_obj = ProgramSpecificAuth.new(nil, nil)
    assert_false auth_obj.is_uid_email?

    auth_obj.uid = "123"
    assert_false auth_obj.is_uid_email?

    auth_obj.uid = "sun@chronus.com"
    assert auth_obj.is_uid_email?
  end

  def test_set_member
    member_1 = members(:f_admin)
    member_2 = members(:ram)
    google_oauth = member_1.organization.google_oauth

    # from import email
    auth_obj = ProgramSpecificAuth.new(google_oauth, nil)
    auth_obj.uid = member_1.email
    auth_obj.import_data = { Member.name => { "email" => member_2.email } }
    auth_obj.set_member!(true, OpenAuth)
    assert_equal member_2, auth_obj.member

    # from email (uid)
    auth_obj.import_data = nil
    auth_obj.member = nil
    auth_obj.set_member!(true, OpenAuth)
    assert_equal member_1, auth_obj.member

    # from uid
    member_2.login_identifiers.create!(auth_config: google_oauth, identifier: member_1.email)
    auth_obj.member = nil
    auth_obj.set_member!(true, OpenAuth)
    assert_equal member_2, auth_obj.member
  end

  def test_set_member_guard_conditions
    auth_obj = ProgramSpecificAuth.new(nil, nil)
    auth_obj.uid = "12345"
    auth_obj.expects(:set_member_from_uid!).never
    auth_obj.expects(:set_member_from_email!).never
    auth_obj.set_member!(true, ChronusAuth)
    auth_obj.set_member!(false, OpenAuth)

    auth_obj.status = ProgramSpecificAuth::Status::AUTHENTICATION_FAILURE
    auth_obj.set_member!(true, OpenAuth)

    auth_obj.status = nil
    auth_obj.uid = nil
    auth_obj.set_member!(true, OpenAuth)

    auth_obj.uid = "12345"
    auth_obj.expects(:set_member_from_uid!).once
    auth_obj.expects(:set_member_from_email!).once
    auth_obj.set_member!(true, OpenAuth)
  end

  def test_set_status
    auth_obj = ProgramSpecificAuth.new(nil, nil)
    auth_obj.uid = "12345"
    auth_obj.set_status!(true)
    assert auth_obj.no_user_existence?

    auth_obj.stubs(:deny_permission?).returns(true)
    auth_obj.status = nil
    auth_obj.set_status!(true)
    assert auth_obj.permission_denied?

    auth_obj.member = members(:inactive_user)
    auth_obj.status = nil
    auth_obj.set_status!(true)
    assert auth_obj.member_suspended?

    auth_obj.member = members(:f_admin)
    auth_obj.status = nil
    auth_obj.set_status!(true)
    assert auth_obj.authenticated?

    auth_obj.prioritize_validation = true
    auth_obj.status = nil
    auth_obj.set_status!(true)
    assert auth_obj.permission_denied?

    auth_obj.status = nil
    auth_obj.set_status!(false)
    assert auth_obj.authentication_failure?

    auth_obj.uid = ""
    auth_obj.status = nil
    auth_obj.set_status!(true)
    assert auth_obj.authentication_failure?
  end

  def test_authenticate
    args = ["email", "password"]
    auth_config = programs(:org_primary).chronus_auth
    auth_obj = ProgramSpecificAuth.new(auth_config, args)

    ProgramSpecificAuth.expects(:new).with(auth_config, args).returns(auth_obj)
    ChronusAuth.expects(:authenticate?).with(auth_obj, {}).once
    auth_obj.expects(:set_member!).once
    auth_obj.expects(:set_status!).once
    assert_equal auth_obj, ProgramSpecificAuth.authenticate(auth_config, *args)
  end

  def test_set_member_from_email_when_uid_mismatch
    member = members(:f_mentor)
    google_oauth = member.organization.google_oauth
    member.login_identifiers.create!(auth_config: google_oauth, identifier: "12345")

    auth_obj = ProgramSpecificAuth.new(google_oauth, nil)
    auth_obj.uid = member.email
    auth_obj.set_member!(true, OpenAuth)
    auth_obj.member = nil
    assert auth_obj.authentication_failure?
    assert_equal "Please login using the credentials used during signup.", auth_obj.error_message
  end
end