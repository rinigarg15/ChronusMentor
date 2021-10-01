module SamlAutomatorUtils

  module RegexPatterns
    SP_METADATA_FILE = /^[\d]{14}_SP_Metadata\.xml$/
    IDP_METADATA_FILE = /^[\d]{14}_IDP_Metadata\.xml$/
    PASSPHRASE_FILE = /^[\d]{14}_passphrase$/
    CERT_FILE = /^[\d]{14}_cert\.pem$/
    KEY_FILE = /^[\d]{14}_key\.pem$/
  end

  def self.setup_saml_auth_config(organization, options = {})
    saml_setup_success = true
    files = {}
    begin
      files = SamlAutomatorUtils::SamlFileUtils.get_saml_files_from_s3(organization.id)
      ActiveRecord::Base.transaction do
        saml_auth_config = organization.auth_configs.find_or_create_by(auth_type: AuthConfig::Type::SAML)
        saml_options = self.get_saml_options(organization, files, options)
        saml_auth_config[:title] ||= "feature.program.header.saml_default_title".translate
        saml_auth_config.set_options!(saml_options)
      end
    rescue => exception
      saml_setup_success = false
      Airbrake.notify(exception, error_message: "SAML Auth Config setup failed for organization with id = #{organization.id}")
    ensure
      files.values.each { |f| File.delete(f[:path]) if f[:path].present? } if files.present?
    end
    saml_setup_success
  end

  def self.generate_sp_metadata_file(organization)
    dirname = SamlAutomatorUtils::SamlFileUtils.get_basepath
    timestamp = dirname.split("/").last
    FileUtils.mkdir_p(dirname, mode: 0777)
    passphrase_file = File.join(dirname, "#{timestamp}_passphrase")
    cert_file = File.join(dirname, "#{timestamp}_cert.pem")
    key_file = File.join(dirname, "#{timestamp}_key.pem")
    sp_metadata_file = File.join(dirname, "#{timestamp}_SP_Metadata.xml")
    config_file = File.join(Rails.root.to_s, 'config', 'saml_configs', Rails.env)
    config_file = File.exist?(config_file) ? config_file : File.join(Rails.root.to_s, 'config', 'saml_configs', 'default')

    self.generate_passphrase(passphrase_file)
    self.generate_private_key_and_cert(key_file, cert_file, passphrase_file, config_file)
    self.generate_metadata_xml(organization, sp_metadata_file, key_file, cert_file)
    files_to_transfer = [[passphrase_file, "text/plain"], [cert_file, "text/plain"], [key_file, "text/plain"], [sp_metadata_file, "application/xml"]]
    SamlAutomatorUtils::SamlFileUtils.transfer_files_to_s3(files_to_transfer, organization.id)
    sp_metadata_file
  end

  def self.get_saml_idp_certificate(organization)
    saml_auth_config = organization.saml_auth
    return unless saml_auth_config.present?

    saml_options = saml_auth_config.get_options
    idp_certificate = self.strip_begin_end_certificate(saml_options["idp_base64_cert"])
    self.enclose_begin_end_certificate(idp_certificate)
  end

  private

  def self.get_encoded_cert_content_and_fingerprint(encoded_cert_text)
    cert_text = Base64.decode64(encoded_cert_text)
    cert = OpenSSL::X509::Certificate.new(cert_text)
    return [encoded_cert_text, Digest::SHA1.hexdigest(cert.to_der)]
  end

  def self.get_saml_options(organization, saml_files, options)
    saml_options = {}
    idp_metadata = File.read(saml_files[:idp_metadata][:path])
    if options[:update_certificate_only]
      saml_options = organization.saml_auth.get_options
    else
      saml_options["idp_destination"] = saml_options["idp_sso_target_url"] = self.get_sso_target_url(idp_metadata)
      saml_options["xmlsec_privatekey"] = File.read(saml_files[:key][:path])
      saml_options["xmlsec_certificate"] = File.read(saml_files[:cert][:path])
      saml_options["xmlsec_privatekey_pwd"] = File.read(saml_files[:passphrase][:path])
      saml_options["issuer"] = organization.url
    end

    encoded_cert_text = if options[:idp_certificate].present?
      self.strip_begin_end_certificate(options[:idp_certificate])
    else
      self.get_encoded_cert_text_from_metadata(idp_metadata)
    end
    idp_base64_cert, idp_cert_fingerprint = SamlAutomatorUtils.get_encoded_cert_content_and_fingerprint(encoded_cert_text)
    saml_options["idp_base64_cert"] = idp_base64_cert
    saml_options["idp_cert_fingerprint"] = idp_cert_fingerprint
    saml_options
  end

  def self.strip_begin_end_certificate(idp_certificate)
    return unless idp_certificate

    idp_certificate.gsub(/\w*-+(BEGIN|END) CERTIFICATE-+\w*/, "").gsub("\r\n", "").strip
  end

  def self.enclose_begin_end_certificate(idp_certificate)
    return unless idp_certificate

    "-----BEGIN CERTIFICATE-----\r\n#{idp_certificate}\r\n-----END CERTIFICATE-----\r\n"
  end

  def self.get_sso_target_url(file)
    xml = Nokogiri::XML.parse(file)
    binding = "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect"
    nodes = xml.xpath("//*[local-name()='EntityDescriptor']//*[local-name()='IDPSSODescriptor']//*[local-name()='SingleSignOnService']")
    node = nodes.find { |n| n["Binding"] == binding }
    node["Location"]
  end

  def self.get_encoded_cert_text_from_metadata(file)
    document = LibXML::XML::Document.string(file)
    base64_cert = document.find_first("//ds:X509Certificate", Onelogin::NAMESPACES)
    base64_cert.content
  end

  def self.generate_passphrase(file)
    File.open(file, 'w') { |f| f.write SecureRandom.urlsafe_base64 }
  end

  def self.generate_private_key_and_cert(key_file, cert_file, passphrase_file, config_file)
    system("openssl genrsa -des3 -passout file:'#{passphrase_file}' -out '#{key_file}' 2048")
    system("openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout '#{key_file}' -out '#{cert_file}' -passin file:'#{passphrase_file}' -config '#{config_file}'")
  end

  def self.generate_metadata_xml(organization, sp_metadata_file, key_file, cert_file)
    saml_settings = Onelogin::Saml::Settings.new
    saml_settings.xmlsec_certificate = File.read(cert_file)
    saml_settings.xmlsec_privatekey = File.read(key_file)
    saml_settings.xmlsec1_path = "xmlsec1"
    saml_settings.assertion_consumer_service_url = "https://#{organization.url}/session"
    saml_settings.issuer = organization.url

    File.open(sp_metadata_file, "w") { |f| f.write Onelogin::Saml::MetaData.create(saml_settings) }
  end

  module SamlFileUtils
    include ChronusS3Utils

    def self.transfer_files_to_s3(files, organization_id, options = {})
      s3_prefix = "#{SAML_SSO_DIR}/#{organization_id}"
      files.each do |file, content_type|
        options.merge!(url_expires: 7.days, content_type: content_type, discard_source: false)
        S3Helper.transfer(file, s3_prefix, APP_CONFIG[:chronus_mentor_common_bucket], options)
      end
    end

    def self.write_file_to_local(source_file, options = { s3_file: true })
      dirname = self.get_basepath
      timestamp = dirname.split("/").last
      FileUtils.mkdir_p(dirname, mode: 0777)
      filename = options[:s3_file] ? source_file.key : "#{timestamp}_#{options[:file_name_suffix]}"
      local_file = File.join(dirname, File.basename(filename))
      File.open(local_file, "wb") { |f| f.write(source_file.read) }
      local_file
    end

    def self.copy_file_from_s3(organization_id, file_regex)
      latest_file = self.get_latest_file_from_s3(organization_id, file_regex)
      if latest_file.present?
        local_file = self.write_file_to_local(latest_file)
      end
      local_file
    end

    def self.check_if_files_present_in_s3(organization_id, file_regexes)
      file_regexes.all? do |file_regex|
        self.get_files_from_s3(organization_id, file_regex).present?
      end
    end

    private

    def self.get_saml_files_from_s3(organization_id)
      files = {
        idp_metadata: { path: "", regex: SamlAutomatorUtils::RegexPatterns::IDP_METADATA_FILE },
        passphrase: { path: "", regex: SamlAutomatorUtils::RegexPatterns::PASSPHRASE_FILE },
        cert: { path: "", regex: SamlAutomatorUtils::RegexPatterns::CERT_FILE },
        key: { path: "", regex: SamlAutomatorUtils::RegexPatterns::KEY_FILE }
      }
      files.each do |file_key, file_info|
        file_info[:path] = self.copy_file_from_s3(organization_id, file_info[:regex])
        raise "\nFile not found in S3\n\torganization ID - #{organization_id}\n\tFile - #{file_key}\n" unless file_info[:path].present?
      end
      files
    end

    def self.get_latest_file_from_s3(organization_id, file_regex)
      objects = self.get_files_from_s3(organization_id, file_regex)
      objects.sort_by(&:key).reverse[0]
    end

    def self.get_files_from_s3(organization_id, file_regex)
      objects_with_prefix = S3Helper.get_objects_with_prefix(APP_CONFIG[:chronus_mentor_common_bucket], "#{SAML_SSO_DIR}/#{organization_id}/")
      objects = objects_with_prefix.select { |object| File.basename(object.key).match(file_regex) }
      objects
    end

    def self.get_basepath
      timestamp = Time.now.utc.strftime('%Y%m%d%H%M%S')
      File.join(Rails.root.to_s, 'tmp', timestamp)
    end

  end

end