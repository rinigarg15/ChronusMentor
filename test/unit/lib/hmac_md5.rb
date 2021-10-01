require_relative './../../test_helper.rb'

class HmacMD5Test < ActiveSupport::TestCase
  def test_encrypt
    assert_equal "9d5c73ef85594d34ec4438b7c97e51d8", EncryptionEngine::HMAC::MD5.hash("key","data")
  end
end