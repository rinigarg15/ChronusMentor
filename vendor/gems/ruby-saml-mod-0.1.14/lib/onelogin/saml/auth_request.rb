module Onelogin::Saml
  class AuthRequest
    
    attr_reader :settings, :id, :request_xml, :forward_url
    
    def initialize(settings)
      @settings = settings
    end
    
    def self.create(settings)
      ar = AuthRequest.new(settings)
      ar.generate_request
    end
    
    def generate_request
      @id = Onelogin::Saml::AuthRequest.generate_unique_id(42)
      issue_instant = Onelogin::Saml::AuthRequest.get_timestamp

      request_doc = REXML::Document.new
      request_doc.context[:attribute_quote] = :quote
      root = request_doc.add_element "samlp:AuthnRequest", { "xmlns:samlp" => "urn:oasis:names:tc:SAML:2.0:protocol" }
      root.attributes['ID'] = @id
      root.attributes['IssueInstant'] = issue_instant
      root.attributes['Version'] = "2.0"

      if @settings.idp_destination != nil
        root.attributes['Destination'] = @settings.idp_destination
      end

      root.attributes["AssertionConsumerServiceURL"] = Array(@settings.assertion_consumer_service_url).first
      #ProtocolBinding=\"urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST\"

      if @settings.issuer != nil
        issuer = root.add_element "saml:Issuer", { "xmlns:saml" => "urn:oasis:names:tc:SAML:2.0:assertion" }
        issuer.text = @settings.issuer
      end

      if @settings.name_identifier_format != nil
        root.add_element "samlp:NameIDPolicy", { 
          "xmlns:samlp" => "urn:oasis:names:tc:SAML:2.0:protocol",
          # Might want to make AllowCreate a setting?
          "AllowCreate" => "true",
          "Format" => @settings.name_identifier_format
        }
      end

      if @settings.requested_authn_context
        requested_context = root.add_element "samlp:RequestedAuthnContext", { 
          "xmlns:samlp" => "urn:oasis:names:tc:SAML:2.0:protocol",
          "Comparison" => "exact",
        }
        class_ref = requested_context.add_element "saml:AuthnContextClassRef", { 
          "xmlns:saml" => "urn:oasis:names:tc:SAML:2.0:assertion",
        }     
        class_ref.text = @settings.requested_authn_context
      end

      @request_xml = ""
      request_doc.write(@request_xml)

      Rails.logger.debug "Created AuthnRequest: #{@request_xml}"

      deflated_request  = Zlib::Deflate.deflate(@request_xml, 9)[2..-5]
      base64_request    = Onelogin::Saml::AuthRequest.base64_encoding(deflated_request, @settings.strict_encoding)
      encoded_request   = CGI.escape(base64_request)

      if @settings.authn_signed
        concat_params_string = "SAMLRequest=" + encoded_request + "&" + "SigAlg=" + CGI.escape("http://www.w3.org/2000/09/xmldsig#rsa-sha1")

        private_key = @settings.get_private_key
        signed_string =  Onelogin::Saml::AuthRequest.base64_encoding(private_key.sign(OpenSSL::Digest::SHA1.new, concat_params_string), true)
        encoded_query_string = CGI.escape(signed_string)

        query_string = concat_params_string + "&" + "Signature=" + encoded_query_string
      else
        query_string = "SAMLRequest=" + encoded_request
      end

      @forward_url = @settings.idp_sso_target_url + (@settings.idp_sso_target_url.include?("?") ? "&" : "?") + query_string
    end

    private

    def self.base64_encoding(request, is_strict_encoding = false)
      is_strict_encoding.present? ? Base64.strict_encode64(request) : Base64.encode64(request)
    end

    def self.generate_unique_id(length)
      chars = ("a".."f").to_a + ("0".."9").to_a
      chars_len = chars.size
      unique_id = ("a".."f").to_a[rand(6)]
      2.upto(length) { |i| unique_id << chars[rand(chars_len)] }
      unique_id
    end

    def self.get_timestamp
      Time.new.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
    end
  end
end
