# Refer config/initilializers/net_ldap_overrides.rb 
# for changes made to net-ldap gem to support TLS certificate verification

class LDAPAuth < ModelAuth
  # http://net-ldap.rubyforge.org/Net/LDAP.html#method-i-bind

  def self.authenticate?(auth_obj, options)
    auth_obj.uid = auth_obj.data[0]
    password = auth_obj.data[1]

    # The attribute which maps user with his username in LDAP server
    dn_attribute = options["dn_attribute"]
    base = options["base"]

    port = options["port"] || ( options["secure"] ? "636" : "389" )

    # If the customer's ldap server requires authentication to do the binding use 
    # { :method => :simple,  :username => binding_username, :password => binding_password }
    # { :method => :anonymous }
    binding_auth = options["binding_auth"]

    # peer_cert is the public certificate which openssl uses to decrypt the data which is sent over ssl
    # we find the root CA of the customer's server and add it as cert_store
    # adds an additional layer of security to prevent malicious attacks by posing as our ldaps server
    # raises airbrake exception - certificate verify failed
    cert_store = OpenSSL::X509::Store.new if options["cert_store"]
    
    cert_store.add_cert OpenSSL::X509::Certificate.new(options["cert_store"]) if options["cert_store"]

    ldap = Net::LDAP.new({
                            :host => options["host"], 
                            :port => port,
                            :auth => binding_auth,
                            :encryption =>  (:simple_tls if options["secure"]),
                            :cert_store => (cert_store if options["cert_store"])
                          }.reject{ |k,v| v.nil? }) 

    if auth_obj.uid.present? && password.present?
      result_set = ldap.bind_as(  :base => base, 
                                :filter => Net::LDAP::Filter.eq(dn_attribute, auth_obj.uid), 
                                :password => password)
      operation_result = ldap.get_operation_result.message
      is_valid = !!result_set
      if is_valid
        return is_valid
      elsif operation_result == "Success"
        auth_obj.error_message = "User not found"
        return false
      else
        auth_obj.error_message = operation_result
        return false
      end
    else
      auth_obj.error_message = "Invalid Credentials - Please fill in all details"
      return false
    end
  end
end

# Example AuthConfig
# ac = AuthConfig.new
# ac.organization_id = 1
# ac.auth_type = "LDAPAuth"
# host = "SECURELDAP.UMC.EDU"
# port = "636"
# base = "OU=UMMCAPPS-EXT,DC=NTUMMC,DC=UMSMED,DC=EDU"
# binding_username = "CN=ChronusMentor,ou=Service Accounts,ou=UMC-Users,ou=ummcapps-ext,dc=ntummc,dc=umsmed,dc=edu"
# binding_password = "Test1mentor"
# binding_auth = { :method => :simple,  :username => binding_username, :password => binding_password }
# dn_attribute = "sAMAccountName"
# cert_store = File.read("/home/hasan/projects/temp/ldap_sso/PCA-3G5.pem")
# options = {"host" => host, "port" => port, "dn_attribute" => dn_attribute, "binding_auth" => binding_auth, "base" => base, "secure"=>true, "cert_store"=>cert_store}
# ac.title = "LDAP login"
# ac.set_options!(options)

