require_relative './../../test_helper.rb'

class DESTest < ActiveSupport::TestCase

  def test_encrypt
    assert_equal "br7kKdZJFSlQKenkQ86Rkw==\n", cipher.encrypt("Sundar Raja")
  end

  def test_decrypt
    assert_equal "Sundar Raja", cipher.decrypt("br7kKdZJFSlQKenkQ86Rkw==\n")
  end

  private

  def cipher
    EncryptionEngine::DES.new("DES", "TEST12345")
  end
end