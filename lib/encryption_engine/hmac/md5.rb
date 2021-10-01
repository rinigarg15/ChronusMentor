module EncryptionEngine
  module HMAC
    class MD5
      def self.hash(key, data)
        digest = OpenSSL::Digest::Digest.new('MD5')
        OpenSSL::HMAC.hexdigest(digest, key, data)
      end
    end
  end
end