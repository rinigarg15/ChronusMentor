require 'rsa_helper'

# Option keys are "private_key", "url"
class OpenSSLAuth < ModelAuth

  def self.authenticate?(auth_obj, options)
    rsa = RsaHelper::CryptEngine.new(options["private_key"])
    decrypted_data = rsa.decrypt(auth_obj.data[0])
    auth_obj.uid = decrypted_data unless decrypted_data.nil?

    return !decrypted_data.nil?
  end
end