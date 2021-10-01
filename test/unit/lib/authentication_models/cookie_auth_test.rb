require_relative './../../../test_helper'

class CookieAuthTest < ActiveSupport::TestCase

  def test_authenticate_success
    member = members(:f_admin)
    auth_config = AuthConfig.create!(auth_type: AuthConfig::Type::Cookie, organization: member.organization)
    member.login_identifiers.create!(auth_config: auth_config, identifier: "Test123")
    options = get_options
    auth_obj = ProgramSpecificAuth.new(auth_config, [ { encrypted_uid: encrypt_data("Test123", options) } ])
    assert CookieAuth.authenticate?(auth_obj, options)
    assert_equal auth_obj.member, member
  end

  def test_authenticate_fail_with_invalid_member
    options = get_options
    auth_config = AuthConfig.new(auth_type: AuthConfig::Type::Cookie, organization: programs(:org_primary))
    auth_obj = ProgramSpecificAuth.new(auth_config, [ { encrypted_uid: encrypt_data("Test123", options) } ])
    assert_false CookieAuth.authenticate?(auth_obj, options)
    assert_equal auth_obj.status, ProgramSpecificAuth::Status::AUTHENTICATION_FAILURE
    assert_equal auth_obj.uid, "Test123"
    assert_equal auth_obj.error_message, "We're sorry, but access to this page is limited to SPE members only. If you believe you received this page in error, please contact Customer Service at 1.972.952.9393 or service@spe.org. If you are not a member, please use the Back button on your browser to continue your session on SPE.org."
  end

  def test_authenticate_fail
    auth_config = AuthConfig.new(auth_type: AuthConfig::Type::Cookie, organization: programs(:org_primary))
    auth_obj = ProgramSpecificAuth.new(auth_config, [])
    assert_false CookieAuth.authenticate?(auth_obj, get_options)
  end

  private

  def get_options
    {
      login_url: "https://qa.spe.org/appssecured/login/servlet/TpSSOServlet?resource=chronusLandingURL",
      logout_url: "https://qa.spe.org/appssecured/login/servlet/TpSSOServlet?command=logout",
      organization: "spe",
      "encryption" => { "class" => "EncryptionEngine::DES", "options" => { "mode" => "DES", "key" => "TESTKEY1", "iv" => nil } }
    }
  end

  def encrypt_data(data, options)
    encryption_options = options["encryption"]["options"]
    cipher = options["encryption"]["class"].constantize.new(encryption_options["mode"], encryption_options["key"], encryption_options["iv"])
    cipher.encrypt(data)
  end
end