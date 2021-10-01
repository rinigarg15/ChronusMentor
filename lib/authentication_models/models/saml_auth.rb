# Option keys are
# "idp_sso_target_url",
# "idp_cert_fingerprint",
# "issuer"
# "name_identifier_format" optional
# "xmlsec_certificate"
# "xmlsec_privatekey"
# "xmlsec_privatekey_pwd" if the private key is created with passphrase
# "friendly_name"          optional, This is required if nameId is not being used as uid and we rely on SAML attributes. If we use FriendlyName for parsing, then set this to attribute name.
# "name_parser"            optional, This is required if nameId is not being used as uid and we rely on SAML attributes. To parse SAML attributes we generally use FriendlyName for parsing, if we wish to parse using Name, then this should be set to that attribute name.
# "idp_destination"        optional (Note: This was required for PNC and it was same as idp_sso_target_url.)
# "authn_signed"           optional, Default is false - This is required if you need to sign the Authnrequest
# "skip_authn_context"     optional, Default is false - http://docs.oasis-open.org/security/saml/v2.0/saml-authn-context-2.0-os.pdf
# "import_data"            optional, Default is false - e.g. {"name_identifier" => "Name", "attributes" => { "Member" => {"first_name" => "FirstName","last_name" => "LastName", "email" => "Email"} }}
# "validate"               optional, To include custom validations.
# "idp_slo_target_url"     optional, If customer require Single Log Out, Url to send SAML Logout Request
# "strict_encoding"        optional, If strict base64 encoding have to be performed. Base64.encode64 adds line break for every 60th character. If line break have to be removed, then Base64.strict_encode64 will be used.

class SAMLAuth < ModelAuth
  def self.authenticate?(auth_obj, options = {})
    response = Onelogin::Saml::Response.new(auth_obj.data[0], auth_obj.auth_config.saml_settings())

    status = response.is_valid?
    auth_obj.uid = get_uid(response, options)
    set_variables_required_for_slo(response, options, auth_obj)

    if options["validate"].present?
      response_attributes = get_response_attributes(response, options["validate"]["name_identifier"])
      self.validate_attributes_from_sso(auth_obj, options, response_attributes)
    end

    if options["import_data"].present?
      response_attributes = get_response_attributes(response, options["import_data"]["name_identifier"])
      auth_obj.import_data = imported_data(options, response_attributes)
    end
    return status
  end

  def self.get_attributes_for_saml_slo(attributes)
    {
      name_id: attributes[:name_id],
      session_index: attributes[:session_index],
      name_qualifier: attributes[:name_qualifier]
    }
  end

  private

  def self.get_uid(response, options)
    if options["friendly_name"].present?
      response.saml_attributes_friendly_name[options["friendly_name"]]
    elsif options["name_parser"].present?
      response.saml_attributes_name[options["name_parser"]]
    else
      response.name_id
    end
  end

  def self.set_variables_required_for_slo(response, options, auth_obj)
    return unless options["idp_slo_target_url"].present?
    auth_obj.name_qualifier = response.name_qualifier
    auth_obj.session_index = response.session_index
    auth_obj.slo_enabled = true
    auth_obj.name_id = response.name_id
  end

  def self.get_response_attributes(response, name_identifier)
    if name_identifier == "Name"
      response.saml_attributes_name
    elsif name_identifier == "FriendlyName"
      response.saml_attributes_friendly_name
    else
      {}
    end
  end
end

#Instructions for SAML Auth, top level steps
# 1. Generate SP (Chronus) metadata xml & send the metadata to customer
# 2. Get Idp (Customer) metadata xml
# 3. Configure the options using the info in metadata files

# Generate SP metadata.xml & [xmlsec_privatekey, xmlsec_certificate, xmlsec_privatekey_pwd]
# 1. Generate key - openssl genrsa -des3 -out pnc_sb_key.pem 2048 (Here des3 is for making it pass phrase protected, make sure remember the pass phrase)
# 2. Generate certificate - openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout pnc_sb_key.pem -out pnc_sb_cert.pem
#    The following info is required to generate the certificate issuer=/C=US/ST=Arizona/L=Scottsdale/O=Chronus Corp/OU=Mentor/CN=*.chronus.com/emailAddress=ops@chronus.com
# 3. Generate metadata.xml
#
# options = {} # Keys should be "xmlsec_certificate", "xmlsec_privatekey"
# settings =  Onelogin::Saml::Settings.new(options)
# settings.xmlsec1_path = "xmlsec1"
# settings.assertion_consumer_service_url = "https://saml.realizegoal.com/session" (This should change based on the program)
# settings.issuer = "saml.realizegoal.com" (This should change based on the program)
#
# f = File.open("sso/SAML/pnc_sb_SP_metadata.xml", "w")
# f.puts Onelogin::Saml::MetaData.create(settings)
# f.close


# Configuring the options using Idp metadata
# 1. "idp_sso_target_url" We can find this as Location value of "EntityDescriptor -> IDPSSODescriptor -> SingleSignOnService" with "Binding"
#                         as "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect"
# 2. "idp_cert_fingerprint"
#
# document = LibXML::XML::Document.string(File.read(file_path))
# base64_cert = document.find_first("//ds:X509Certificate", Onelogin::NAMESPACES)
# cert_text = Base64.decode64(base64_cert.content)
# cert = OpenSSL::X509::Certificate.new(cert_text)
# idp_cert_fingerprint = Digest::SHA1.hexdigest(cert.to_der)
#
# 3. name_identifier_format (optional, suggested default blank)
# 4. xmlsec_privatekey = File.read("pnc_sb_key.pem")
# 5. xmlsec_certificate = File.read("pnc_sb_cert.pem")
# 6. xmlsec_privatekey_pwd - This will be the passphrase you used to generate the key
# 7. friendly_name - (optional, suggested default blank - if not Get from customer)
# 8. name_parser - (optional,suggested default blank - if not Get from customer)
# 9. idp_destination = idp_sso_target_url
# 10. authn_signed (optional, suggested default false)
# 11. skip_authn_context (optional, suggested default true) - http://docs.oasis-open.org/security/saml/v2.0/saml-authn-context-2.0-os.pdf
# 12. issuer (Is set to the same value during metadata generation)

# To import data from SAML response, use the following auth_config options format
# e.g.,
# options["name_parser"] = "MemberNumber"
# options["import_data"] = {"name_identifier" => "Name", "attributes" => { "Member" => {"first_name" => "FirstName","last_name" => "LastName", "email" => "Email"}, "ProfileAnswer" => {"profile_question_id" => "attribute_name_in_response"} } }
# In above example MemberNumber is the name_parser
# options["idp_slo_target_url"] = url to send SAML Logout Request

# To include custom validations
# e.g.,
# options["validate"] = {"name_identifier" => "Name", "criterias" => [{"criteria" => [{ "attribute" => "Society", "operator" => "eq", "value" => "S1" }]}], "fail_message" => "Not a member of society S1. Please register"}
# In the above example, only users belonging to 'S1 Society' can join the program.
# Supported operators: ["eq" | "regex"]; Permission denied message can also be customized using "fail_message" key.
# "strict_encoding" (optional, default false. Base64.encode64 adds line break for every 60th character. If line break have to be removed, then Base64.strict_encode64 have to be used.)