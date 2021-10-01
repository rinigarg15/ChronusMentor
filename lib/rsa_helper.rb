require 'openssl'
require 'base64'

module RsaHelper
  class CryptEngine
    def initialize(private_key, public_key = nil)
      @private   = get_key private_key
      @public    = get_key public_key if public_key
    end

    def encrypt message
      Base64::encode64(@public.public_encrypt(message)).rstrip
    end

    def decrypt message
      return @private.private_decrypt(Base64::decode64(message))
    rescue OpenSSL::PKey::RSAError # Case where decoding is not possible due to message corruption
    end

    def self.generate_keys data_path
      rsa_path = File.join(data_path, 'rsa')
      privkey  = File.join(rsa_path, 'id_rsa')
      pubkey   = File.join(rsa_path, 'id_rsa.pub')
      unless File.exists?(privkey) || File.exists?(pubkey)
        keypair  = OpenSSL::PKey::RSA.generate(1024)
        Dir.mkdir(rsa_path) unless File.exist?(rsa_path)
        File.open(privkey, 'w') { |f| f.write keypair.to_pem } unless File.exists? privkey
        File.open(pubkey, 'w') { |f| f.write keypair.public_key.to_pem } unless File.exists? pubkey
      end
    end

    private
    def get_key string
      OpenSSL::PKey::RSA.new string
    end
  end
end
