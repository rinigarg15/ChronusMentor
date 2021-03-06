module Onelogin::Saml
  class Response
    
    attr_reader :settings, :document, :decrypted_document, :xml, :response
    attr_reader :name_id, :name_qualifier, :session_index, :saml_attributes_friendly_name, :saml_attributes_name
    attr_reader :status_code, :status_message
    attr_reader :in_response_to, :destination
    attr_reader :validation_error
    def initialize(response, settings)
      @response = response
      @settings = settings
      
      begin
        @xml = Base64.decode64(@response)
        @document = LibXML::XML::Document.string(@xml)
        @document.extend(XMLSecurity::SignedDocument)
      rescue => e
        # could not parse document, everything is invalid
        @response = nil
        return
      end
      
      @decrypted_document = LibXML::XML::Document.document(@document)
      @decrypted_document.extend(XMLSecurity::SignedDocument)
      @decrypted_document.decrypt(@settings)
      
      @in_response_to = @decrypted_document.find_first("/samlp:Response", Onelogin::NAMESPACES)['InResponseTo'] rescue nil
      @destination = @decrypted_document.find_first("/samlp:Response", Onelogin::NAMESPACES)['Destination'] rescue nil
      @name_id = @decrypted_document.find_first("/samlp:Response/saml:Assertion/saml:Subject/saml:NameID", Onelogin::NAMESPACES).content rescue nil
      @saml_attributes_friendly_name = {}
      @saml_attributes_name = {}
      #FIXME: Move this logic inside saml_auth.rb i.e., remove custom code from gem
      @decrypted_document.find("//saml:Attribute", Onelogin::NAMESPACES).each do |attr|
        @saml_attributes_friendly_name[attr['FriendlyName']] = attr.content.strip rescue nil
        @saml_attributes_name[attr['Name']] = attr.content.strip rescue nil
      end
      @name_qualifier = @decrypted_document.find_first("/samlp:Response/saml:Assertion/saml:Subject/saml:NameID", Onelogin::NAMESPACES)["NameQualifier"] rescue nil
      @session_index = @decrypted_document.find_first("/samlp:Response/saml:Assertion/saml:AuthnStatement", Onelogin::NAMESPACES)["SessionIndex"] rescue nil
      @status_code = @decrypted_document.find_first("/samlp:Response/samlp:Status/samlp:StatusCode", Onelogin::NAMESPACES)["Value"] rescue nil
      @status_message = @decrypted_document.find_first("/samlp:Response/samlp:Status/samlp:StatusCode", Onelogin::NAMESPACES).content rescue nil
    end
    
    def logger=(val)
      @logger = val
    end
    
    def is_valid?
      if @response.nil? || @response == ""
        @validation_error = "No response to validate"
        return false
      end
      
      if !@settings.idp_cert_fingerprint
        @validation_error = "No fingerprint configured in SAML settings"
        return false
      end
      
      # Verify the original document if it has a signature, otherwise verify the signature
      # in the encrypted portion. If there is no signature, then we can't verify.
      verified = false
      if @document.find_first("//ds:Signature", Onelogin::NAMESPACES)
        verified = @document.validate(@settings.idp_cert_fingerprint, @settings.idp_base64_cert, @logger)
        if !verified
          @validation_error = @document.validation_error
          return false
        end
      end
      
      # Technically we should also verify the signature inside the encrypted portion, but if
      # the cryptext has already been verified, the encrypted contents couldn't have been
      # tampered with. Once we switch to using libxmlsec this won't matter anymore anyway.
      if !verified && @decrypted_document.find_first("//ds:Signature", Onelogin::NAMESPACES)
        verified = @decrypted_document.validate(@settings.idp_cert_fingerprint, @settings.idp_base64_cert, @logger)
        if !verified
          @validation_error = @document.validation_error
          return false
        end
      end
      
      if !verified
        @validation_error = "No signature found in the response"
        return false
      end
      
      true
    end
    
    def success_status?
      @status_code == Onelogin::Saml::StatusCodes::SUCCESS_URI
    end
    
    def auth_failure?
      @status_code == Onelogin::Saml::StatusCodes::AUTHN_FAILED_URI
    end
    
    def no_authn_context?
      @status_code == Onelogin::Saml::StatusCodes::NO_AUTHN_CONTEXT_URI
    end
    
    def fingerprint_from_idp
      if base64_cert = @document.find_first("//ds:X509Certificate", Onelogin::NAMESPACES)
        cert_text = Base64.decode64(base64_cert.content)
        cert = OpenSSL::X509::Certificate.new(cert_text)
        Digest::SHA1.hexdigest(cert.to_der)
      else
        nil
      end
    end
  end
end