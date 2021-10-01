class Net::LDAP

  def initialize(args = {})
    @host = args[:host] || DefaultHost
    @port = args[:port] || DefaultPort
    @verbose = false # Make this configurable with a switch on the class.
    @auth = args[:auth] || DefaultAuth
    @base = args[:base] || DefaultTreebase
    encryption args[:encryption] # may be nil

    # Certificate authority store - should of class OpenSSL::X509::Store
    # Used to store the root CA certificate, which can later be used to authenticate the peer certificate 
    # of secure LDAP certificate
    cert_store args[:cert_store] # may be nil #ADDED

    if pr = @auth[:password] and pr.respond_to?(:call)
      @auth[:password] = pr.call
    end

    # This variable is only set when we are created with LDAP::open. All of
    # our internal methods will connect using it, or else they will create
    # their own.
    @open_connection = nil
  end

  # Function to set certificate store as instance variable
  def cert_store(args)  #ADDED
    @encryption[:cert_store] = args if @encryption
  end
end

class Net::LDAP::Connection

  def self.wrap_with_ssl(io,cert_store=nil) #CHANGED
    raise Net::LDAP::LdapError, "OpenSSL is unavailable" unless Net::LDAP::HasOpenSSL
    ctx = OpenSSL::SSL::SSLContext.new
    # Set the cert_store and force OpenSSL to verifiy the server certificate using it if cert_store is defined
    ctx.cert_store = cert_store if cert_store #ADDED
    ctx.verify_mode = OpenSSL::SSL::VERIFY_PEER if cert_store #ADDED
    conn = OpenSSL::SSL::SSLSocket.new(io, ctx)
    conn.connect
    conn.sync_close = true

    conn.extend(GetbyteForSSLSocket) unless conn.respond_to?(:getbyte)

    conn
  end

  def setup_encryption(args)
    case args[:method]
    when :simple_tls
      @conn = self.class.wrap_with_ssl(@conn, args[:cert_store]) #CHANGED
      # additional branches requiring server validation and peer certs, etc.
      # go here.
    when :start_tls
      msgid = next_msgid.to_ber
      request = [Net::LDAP::StartTlsOid.to_ber].to_ber_appsequence(Net::LDAP::PDU::ExtendedRequest)
      request_pkt = [msgid, request].to_ber_sequence
      @conn.write request_pkt
      be = @conn.read_ber(Net::LDAP::AsnSyntax)
      raise Net::LDAP::LdapError, "no start_tls result" if be.nil?
      pdu = Net::LDAP::PDU.new(be)
      raise Net::LDAP::LdapError, "no start_tls result" if pdu.nil?
      if pdu.result_code.zero?
        @conn = self.class.wrap_with_ssl(@conn)
      else
        raise Net::LDAP::LdapError, "start_tls failed: #{pdu.result_code}"
      end
    else
      raise Net::LDAP::LdapError, "unsupported encryption method #{args[:method]}"
    end
  end
end