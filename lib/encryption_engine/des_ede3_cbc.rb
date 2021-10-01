module EncryptionEngine
  class DesEde3Cbc
    def initialize(key)
      @cipher = OpenSSL::Cipher::Cipher.new("DES-EDE3-CBC")
      @key = Digest::SHA1.hexdigest(key)
    end

    def encrypt(unencrypted_value)
      @cipher = @cipher.encrypt
      @cipher.key = @key
      s = @cipher.update(unencrypted_value.to_s) + @cipher.final
      s.unpack('H*')[0].upcase
    end

    def decrypt(encrypted_value)
      @cipher = @cipher.decrypt
      @cipher.key = @key
      s = [encrypted_value].pack("H*").unpack("C*").pack("c*")

      @cipher.update(s) + @cipher.final
    end
  end
end