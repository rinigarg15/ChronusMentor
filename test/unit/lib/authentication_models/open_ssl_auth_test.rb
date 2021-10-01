require_relative './../../../test_helper'

class OpenSSLAuthTest < ActiveSupport::TestCase

  def test_authenticate_true
    private_key = mock
    OpenSSL::PKey::RSA.expects(:new).at_least(0).returns(private_key)
    private_key.expects(:private_decrypt).with(Base64::decode64("abcd")).returns("123")
    auth_obj = ProgramSpecificAuth.new(open_ssl_auth, ["abcd"])
    assert OpenSSLAuth.authenticate?(auth_obj, "private_key" => "abcd123")
    assert_equal '123', auth_obj.uid
  end

  def test_authenticate_false
    private_key = mock
    OpenSSL::PKey::RSA.expects(:new).at_least(0).returns(private_key)
    private_key.expects(:private_decrypt).with(Base64::decode64("abcd1")).raises(OpenSSL::PKey::RSAError)
    auth_obj = ProgramSpecificAuth.new(open_ssl_auth, ["abcd1"])
    assert_false OpenSSLAuth.authenticate?(auth_obj, "private_key" => "abcd123")
    assert_nil auth_obj.uid
  end

  private

  def open_ssl_auth
    programs(:org_primary).auth_configs.create!(auth_type: AuthConfig::Type::OPENSSL)
  end
end