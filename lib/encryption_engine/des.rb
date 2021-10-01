require 'openssl'
require 'base64'

module EncryptionEngine
  class DES
    def initialize(mode, key, iv = nil, pack_mode = 'm')
      @cipher = OpenSSL::Cipher.new(mode)
      @key = key
      @iv = iv if iv
      @pack_mode = pack_mode
    end

    def encrypt message
      @cipher.encrypt
      @cipher.key = @key
      @cipher.iv = @iv if @iv
      encrypted_bytes = @cipher.update(message)+@cipher.final
      [encrypted_bytes].pack(@pack_mode)
    end

    def decrypt message
      @cipher.decrypt
      @cipher.key = @key
      @cipher.iv = @iv if @iv
      encrypted_bytes = message.unpack(@pack_mode)[0]
      @cipher.update(encrypted_bytes)+@cipher.final
    end
  end
end