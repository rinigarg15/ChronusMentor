require_relative './../test_helper.rb'

class SamlAuthConfigControllerTest < ActionController::TestCase
  def setup
    super
    login_as_super_user
  end

  def test_check_access_saml_sso
    current_member_is :f_mentor
    assert_permission_denied do
      get :saml_sso
    end
  end

  def test_check_access_generate_sp_metadata
    current_member_is :f_mentor
    assert_permission_denied do
      get :generate_sp_metadata
    end
  end

  def test_check_access_upload_idp_metadata
    current_member_is :f_mentor
    assert_permission_denied do
      post :upload_idp_metadata
    end
  end

  def test_check_access_setup_authconfig
    current_member_is :f_mentor
    assert_permission_denied do
      post :setup_authconfig
    end
  end

  def test_saml_sso
    current_member_is :f_admin
    SamlAutomatorUtils::SamlFileUtils.stubs(:check_if_files_present_in_s3).with(programs(:org_primary).id, [SamlAutomatorUtils::RegexPatterns::IDP_METADATA_FILE]).returns(false)
    get :saml_sso
    assert_response :success
    assert_false assigns(:files_present)
    assert_match "SAML SSO Setup", response.body
    assert_equal SamlAuthConfigController::SamlHeaders::UPLOAD_IDP_METADATA, assigns(:saml_tab)
  end

  def test_saml_sso_setup_auth_config_tab
    current_member_is :f_admin
    SamlAutomatorUtils::SamlFileUtils.stubs(:check_if_files_present_in_s3).with(programs(:org_primary).id, [SamlAutomatorUtils::RegexPatterns::IDP_METADATA_FILE, SamlAutomatorUtils::RegexPatterns::SP_METADATA_FILE]).returns(false)
    get :saml_sso, params: { tab: SamlAuthConfigController::SamlHeaders::SETUP_AUTHCONFIG}
    assert_response :success
    assert_false assigns(:files_present)
    assert_equal SamlAuthConfigController::SamlHeaders::SETUP_AUTHCONFIG, assigns(:saml_tab)
  end

  def test_saml_sso_setup_auth_config_tab_files_present
    current_member_is :f_admin
    SamlAutomatorUtils::SamlFileUtils.stubs(:check_if_files_present_in_s3).with(programs(:org_primary).id, [SamlAutomatorUtils::RegexPatterns::IDP_METADATA_FILE, SamlAutomatorUtils::RegexPatterns::SP_METADATA_FILE]).returns(true)
    get :saml_sso, params: { tab: SamlAuthConfigController::SamlHeaders::SETUP_AUTHCONFIG}
    assert_response :success
    assert assigns(:files_present)
    assert_equal SamlAuthConfigController::SamlHeaders::SETUP_AUTHCONFIG, assigns(:saml_tab)
  end

  def test_saml_sso_files_present
    current_member_is :f_admin
    SamlAutomatorUtils::SamlFileUtils.stubs(:check_if_files_present_in_s3).with(programs(:org_primary).id, [SamlAutomatorUtils::RegexPatterns::IDP_METADATA_FILE]).returns(true)
    get :saml_sso
    assert_response :success
    assert assigns(:files_present)
    assert_match "SAML SSO Setup", response.body
    assert_equal SamlAuthConfigController::SamlHeaders::UPLOAD_IDP_METADATA, assigns(:saml_tab)
  end

  def test_upload_idp_metadata_success
    current_member_is :f_admin
    ChronusS3Utils::S3Helper.stubs(:transfer).returns(true)

    post :upload_idp_metadata, params: { file: fixture_file_upload(File.join("files", "saml_sso", "20140925070519_IDP_Metadata.xml"), 'application/xml')}
    assert_redirected_to saml_auth_config_saml_sso_path(tab: SamlAuthConfigController::SamlHeaders::GENERATE_SP_METADATA)
    assert_equal "File uploaded successfully", flash[:notice]
  end

  def test_upload_idp_metadata_error_wrong_file
    current_member_is :f_admin
    ChronusS3Utils::S3Helper.stubs(:transfer).returns(true)

    post :upload_idp_metadata, params: { file: fixture_file_upload(File.join("files", "saml_sso", "20140925070427_passphrase"), 'text/text')}
    assert_redirected_to saml_auth_config_saml_sso_path(tab: SamlAuthConfigController::SamlHeaders::UPLOAD_IDP_METADATA)
    assert_equal "Wrong file uploaded. Please upload Identity Provider Metadata in .xml file.", flash[:error]
  end

  def test_upload_idp_metadata_error_empty_file
    current_member_is :f_admin
    ChronusS3Utils::S3Helper.stubs(:transfer).returns(true)

    post :upload_idp_metadata, params: { file: ""}
    assert_redirected_to saml_auth_config_saml_sso_path(tab: SamlAuthConfigController::SamlHeaders::UPLOAD_IDP_METADATA)
    assert_equal "Error occurred while uploading file. Please upload again.", flash[:error]
  end

  def test_generate_sp_metadata
    current_member_is :f_admin
    SamlAutomatorUtils::SamlFileUtils.stubs(:copy_file_from_s3).returns(nil)
    SamlAutomatorUtils::SamlFileUtils.stubs(:transfer_files_to_s3).returns(true)
    org_domain = members(:f_admin).organization.default_program_domain

    get :generate_sp_metadata
    assert_response :success
    assert_equal "application/xml", response.content_type

    xml_doc = Nokogiri.XML(response.body.squish.gsub("> <", "><"))

    assert_equal ["EntityDescriptor", "SPSSODescriptor", "KeyDescriptor", "KeyInfo", "X509Data", "X509Certificate", "EncryptionMethod", "KeySize", "AssertionConsumerService"], xml_doc.search('*').collect{|a| a.name}

    entity_descriptor = xml_doc.at("EntityDescriptor")
    assert_equal "EntityDescriptor", entity_descriptor.name
    assert_equal "urn:oasis:names:tc:SAML:2.0:metadata", entity_descriptor.namespace.href
    assert_equal org_domain.get_url, entity_descriptor.attr("entityID")

    sp_sso_descriptor = entity_descriptor.child
    assert_equal "SPSSODescriptor", sp_sso_descriptor.name
    assert_equal "urn:oasis:names:tc:SAML:2.0:protocol", sp_sso_descriptor.attr("protocolSupportEnumeration")

    key_descriptor = sp_sso_descriptor.child
    assert_equal "KeyDescriptor", key_descriptor.name
    assert_equal "encryption", key_descriptor.attr("use")

    key_info = key_descriptor.child
    assert_equal "KeyInfo", key_info.name
    assert_equal "http://www.w3.org/2000/09/xmldsig#", key_info.namespace.href

    x509_data = key_info.child
    assert_equal "X509Data", x509_data.name
    x509_certificate = x509_data.child
    assert_equal "X509Certificate", x509_certificate.name

    encryption_method = key_info.next
    assert_equal "EncryptionMethod", encryption_method.name
    assert_equal "http://www.w3.org/2001/04/xmlenc#aes128-cbc", encryption_method.attr("Algorithm")

    key_size = encryption_method.child
    assert_equal "KeySize", key_size.name
    assert_equal "http://www.w3.org/2001/04/xmlenc#", key_size.namespace.href
    assert_equal "128", key_size.text

    assertion_consumer_service = key_descriptor.next
    assert_equal "AssertionConsumerService", assertion_consumer_service.name
    assert_equal "1", assertion_consumer_service.attr("index")
    assert_equal "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST", assertion_consumer_service.attr("Binding")
    assert_equal "#{root_url(host: org_domain.domain, subdomain: org_domain.subdomain, protocol: 'https')}session", assertion_consumer_service.attr("Location")
  end

  def test_setup_authconfig_success
    member = members(:f_admin)

    current_member_is member
    stub_saml_sso_files(member.organization_id)
    assert_difference "AuthConfig.count" do
      post :setup_authconfig
    end
    assert_redirected_to manage_organization_path
    assert_equal "SAML authentication has been setup successfully.", flash[:notice]
    assert member.organization.has_saml_auth?
  end

  def test_resetup_authconfig_success
    member = members(:f_admin)
    organization = member.organization

    current_member_is member
    saml_options = {
      "idp_cert_fingerprint" => "a5857a1d8341301e1c3e1d426157da460859da33",
      "xmlsec_privatekey" => "-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEA17fbELZbup+D/N4kaDwlik/Qrv0cZ4E3QJnAlHrEPTbJzjGp\nrR95OUjf9+lBJf2xE/CV96lm7jGLDPAhwLhltEP6jA/W+6TBcLLXgrb3F4848tB/\nFtU8CcBlHn4dh0/ppMhnWsp7OEXg+O4y2ts9VlPeoh+BnUQkwDPz0p7volax1HRI\nsouvoA2urC5Zr9PC6PqvvpjyrYmTy/5WyKGF0ZtlwqjBtzEeRy3T/b9zr3WZlZ32\nHpvpXewo38NA/0s8zhfK7fstmefvaBc3wjBdmRj14lzMbgN2DWDzDvg7365gNXib\n/UdScKTEqMIKc3bWedjRFbaq43cREPkVYY+LFQIDAQABAoIBAE66LNsGkqeje9oX\ngJYCDXlS88hJW8pyoCWVd3E49NGaY0A7Y79pEybS79pcaIhi8/NhBHpkespHjoXk\nRY0+Pu/xN0lSppUkZeypeHmeKMOSY6hKa3d7zvOIId9lC4XMpmqbMQ0zhJDe/+IZ\nnLm+9b3B0ii88uLgccErtLqTgsVtznZiFzAJl566XGZbwPyr4lLyYL7fGOUV7pE6\nn29nNJ5FmEvY2tOjZOZr5VdgmsSZEypi7lwDrDygMelQkrKBdMmGwrshCqD14Qf8\nZNvd1w9iOkGnaKvhf5JQfouKJR33Wi/EBILhdWeAxHZR7YLmmzNX8Ekca2OCBq3v\nyem/KQECgYEA/E2sc16ou/LbejlxmXfmtNoYJVGQnYL4nqgDyodeu/48arMjJvg4\nlYkt1khGqTdPaj1hf5n1bn0+N+6u+R5FjPlyOK0D6apkwK8PPyE2vz2VlJiE72qM\n55RIWnnQ5EfNYld9KNGVsIsx4o9hdZPXLdzeO7NioI02e/iAPqwXQDUCgYEA2uD1\nzC+NKIwPIQZazUWYbKp1q7MY/UpufzMqIJn73layi6Va2Tnn5UNPmrC4XdcLtSmM\nMa+tTlPc8ay+nKiSWzjFCTtsjdSpzMSpN5UbwIJUrMpUFORbkZ8tb82NZrR+iqq7\nolzCAVveFlG8gLMjxz8T7smmV8lMAu6+7NOkO2ECgYBw5CBhjt1ZG5Vw3vshfDDS\ngzOCnzhiAhRUiUEJAgE1hNBrvbPg3/gRkMvdsYFMfd8e3lAd1DmpMokAZeAMv6rH\nJWYiTegOSZvDS5E64hWpBFlFn+j7Z2WcyRCGyzLYsfgIJLVv6jdcQywS/6zP+1Kw\nxr75X46l4Amc9tgLMt1EcQKBgHon0waCA2X9xPPJeCPYE5mSCNoqumeigsi65WgM\niGUuPbdyMaHKj4GEb4kF19+HhSE2bufMBA0TANxgbIFCE2yV4mGkqJD/f0So/Ufo\nD/UAyAEnaoW+bNx42gLr1V7cnUMGxnF3E09u1iPeujWZxP4OVjGOmSelUKbSV/wU\nojQBAoGBAPhq48Wb4RyxnufYy+qIXMvqxyS3BVwyisPHITGyysghXMPfozoJtVVJ\ndq43RlnNURTYGuhYGfHsR3PPKYKrQTXs8OyqpSyruMxE1REMkfo+0H3EPgYpnClH\nRCR0x8kvDwWPpSQFGEiBGzbKDQGYpFOKadrkpHf+lrdYi92lY/uW\n-----END RSA PRIVATE KEY-----\n",
      "xmlsec_certificate" => "-----BEGIN CERTIFICATE-----\nMIIEqjCCA5KgAwIBAgIJANPoN49RcmJ9MA0GCSqGSIb3DQEBBQUAMIGUMQswCQYD\nVQQGEwJVUzEQMA4GA1UECBMHQXJpem9uYTETMBEGA1UEBxMKU2NvdHRzZGFsZTEV\nMBMGA1UEChMMQ2hyb251cyBDb3JwMQ8wDQYDVQQLEwZNZW50b3IxFjAUBgNVBAMU\nDSouY2hyb251cy5jb20xHjAcBgkqhkiG9w0BCQEWD29wc0BjaHJvbnVzLmNvbTAe\nFw0xNTAxMjAwOTE2MDlaFw0yNTAxMTcwOTE2MDlaMIGUMQswCQYDVQQGEwJVUzEQ\nMA4GA1UECBMHQXJpem9uYTETMBEGA1UEBxMKU2NvdHRzZGFsZTEVMBMGA1UEChMM\nQ2hyb251cyBDb3JwMQ8wDQYDVQQLEwZNZW50b3IxFjAUBgNVBAMUDSouY2hyb251\ncy5jb20xHjAcBgkqhkiG9w0BCQEWD29wc0BjaHJvbnVzLmNvbTCCASIwDQYJKoZI\nhvcNAQEBBQADggEPADCCAQoCggEBANe32xC2W7qfg/zeJGg8JYpP0K79HGeBN0CZ\nwJR6xD02yc4xqa0feTlI3/fpQSX9sRPwlfepZu4xiwzwIcC4ZbRD+owP1vukwXCy\n14K29xePOPLQfxbVPAnAZR5+HYdP6aTIZ1rKezhF4PjuMtrbPVZT3qIfgZ1EJMAz\n89Ke76JWsdR0SLKLr6ANrqwuWa/Twuj6r76Y8q2Jk8v+VsihhdGbZcKowbcxHkct\n0/2/c691mZWd9h6b6V3sKN/DQP9LPM4Xyu37LZnn72gXN8IwXZkY9eJczG4Ddg1g\n8w74O9+uYDV4m/1HUnCkxKjCCnN21nnY0RW2quN3ERD5FWGPixUCAwEAAaOB/DCB\n+TAdBgNVHQ4EFgQUwjrOcBBlsKfZKKd+ULhvVe5klscwgckGA1UdIwSBwTCBvoAU\nwjrOcBBlsKfZKKd+ULhvVe5klsehgZqkgZcwgZQxCzAJBgNVBAYTAlVTMRAwDgYD\nVQQIEwdBcml6b25hMRMwEQYDVQQHEwpTY290dHNkYWxlMRUwEwYDVQQKEwxDaHJv\nbnVzIENvcnAxDzANBgNVBAsTBk1lbnRvcjEWMBQGA1UEAxQNKi5jaHJvbnVzLmNv\nbTEeMBwGCSqGSIb3DQEJARYPb3BzQGNocm9udXMuY29tggkA0+g3j1FyYn0wDAYD\nVR0TBAUwAwEB/zANBgkqhkiG9w0BAQUFAAOCAQEA055jMeP+r+TuUvxyz+vp2K3O\nZthUTCfa14zQgENDkUXNpkP/ncPQCzyc5V8e+jxcEmT+WvAsw/5M7fE1il+9ABjT\n8KO7nxjOyWhRpBhZLzdOjldI+cEZeVkg4k0HGoYdUP40rGuhp1xRZXEnjFKjuivb\npAX2gVXt2Kj2hWnrfZOc6bCQ0wmvkYtGaOXsdF32ZJIzO3c3Aod4/zh0aBW7qp1b\nPcmozRp3QbxOxVShfRp6ImWJheWiY0PBOmXP0qs/awZ8xYe38nXCqc7C2rG02Nys\noRl3rt2WIsEX3JifIH3l5HYZnUuwWyA3+bpiPcz8d4bOmn5C/jPntku/Ug+zEQ==\n-----END CERTIFICATE-----\n",
      "friendly_name" => "Saml Previous"
    }
    saml_auth_config = create_saml_auth(organization, {}, saml_options)
    previous_options = saml_auth_config.get_options

    stub_saml_sso_files(organization.id)
    assert_no_difference "AuthConfig.count" do
      post :setup_authconfig
    end
    assert_redirected_to manage_organization_path
    assert_equal "SAML authentication has been setup successfully.", flash[:notice]
    assert_not_equal previous_options, organization.reload.saml_auth.get_options
  end

  def test_download_idp_metadata_redirect_if_saml_auth_absent
    org = programs(:org_primary)
    current_member_is :f_admin
    current_organization_is org
    get :download_idp_metadata
    assert_redirected_to manage_organization_path
  end

  def test_download_idp_metadata
    org = programs(:org_primary)
    org.auth_configs.create!(auth_type: AuthConfig::Type::SAML)
    current_member_is :f_admin
    current_organization_is org
    idp_metadata = File.join(Rails.root.to_s, "test", "fixtures", "files", "saml_sso", "20140925070519_IDP_Metadata.xml")
    SamlAutomatorUtils::SamlFileUtils.stubs(:copy_file_from_s3).returns(idp_metadata)
    get :download_idp_metadata
    assert_response :success
    assert_equal "application/xml", response.content_type
  end

  def test_update_certificate_redirect_if_saml_auth_absent
    org = programs(:org_primary)
    current_member_is :f_admin
    current_organization_is org
    post :update_certificate
    assert_redirected_to manage_organization_path
  end

  def test_update_certificate_from_params
    org = programs(:org_primary)
    org.auth_configs.create!(auth_type: AuthConfig::Type::SAML)
    options = org.saml_auth.get_options
    assert_nil options["idp_base64_cert"]
    assert_nil options["idp_cert_fingerprint"]
    current_member_is :f_admin
    current_organization_is org
    stub_saml_sso_files(org.id)
    post :update_certificate, params: { idp_certificate: fixture_file_upload(File.join("files", "saml_sso", "20140925070427_cert.pem"))}
    options = org.saml_auth.get_options
    assert options["idp_base64_cert"].present?
    assert_equal "bb1892e7f8a23ebcce0cfe5c3045ec3dabadcf3f", options["idp_cert_fingerprint"]
  end

  def test_update_certificate_from_idp_metadata
    org = programs(:org_primary)
    org.auth_configs.create!(auth_type: AuthConfig::Type::SAML)
    options = org.saml_auth.get_options
    assert_nil options["idp_base64_cert"]
    assert_nil options["idp_cert_fingerprint"]
    current_member_is :f_admin
    current_organization_is org
    stub_saml_sso_files(org.id)
    post :update_certificate
    options = org.saml_auth.get_options
    assert options["idp_base64_cert"].present?
    assert_equal "bcdb6805fcc0498d69ed040d15f83f3bf10d05ca", options["idp_cert_fingerprint"]
  end

  def test_download_idp_certificate_redirect_if_saml_auth_absent
    org = programs(:org_primary)
    current_member_is :f_admin
    current_organization_is org
    get :download_idp_certificate
    assert_redirected_to manage_organization_path
  end

  def test_download_idp_certificate_redirect_if_idp_certificate_absent
    org = programs(:org_primary)
    org = programs(:org_primary)
    org.auth_configs.create!(auth_type: AuthConfig::Type::SAML)

    current_member_is :f_admin
    current_organization_is org
    get :download_idp_certificate
    assert_equal "Error occured while downloading IDP certificate.", flash[:error]
    assert_redirected_to saml_auth_config_saml_sso_path(tab: SamlAuthConfigController::SamlHeaders::SETUP_AUTHCONFIG)
  end

  def test_download_idp_certificate
    org = programs(:org_primary)
    idp_certificate = File.read(File.join(Rails.root.to_s, "test", "fixtures", "files", "saml_sso", "sample_idp_certificate.cer"))

    saml_options = {
      "idp_cert_fingerprint" => "b4d4075b108a471ea97910322a1b708c591a397a",
      "idp_base64_cert" => idp_certificate,
      "xmlsec_privatekey" => "-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEA17fbELZbup+D/N4kaDwlik/Qrv0cZ4E3QJnAlHrEPTbJzjGp\nrR95OUjf9+lBJf2xE/CV96lm7jGLDPAhwLhltEP6jA/W+6TBcLLXgrb3F4848tB/\nFtU8CcBlHn4dh0/ppMhnWsp7OEXg+O4y2ts9VlPeoh+BnUQkwDPz0p7volax1HRI\nsouvoA2urC5Zr9PC6PqvvpjyrYmTy/5WyKGF0ZtlwqjBtzEeRy3T/b9zr3WZlZ32\nHpvpXewo38NA/0s8zhfK7fstmefvaBc3wjBdmRj14lzMbgN2DWDzDvg7365gNXib\n/UdScKTEqMIKc3bWedjRFbaq43cREPkVYY+LFQIDAQABAoIBAE66LNsGkqeje9oX\ngJYCDXlS88hJW8pyoCWVd3E49NGaY0A7Y79pEybS79pcaIhi8/NhBHpkespHjoXk\nRY0+Pu/xN0lSppUkZeypeHmeKMOSY6hKa3d7zvOIId9lC4XMpmqbMQ0zhJDe/+IZ\nnLm+9b3B0ii88uLgccErtLqTgsVtznZiFzAJl566XGZbwPyr4lLyYL7fGOUV7pE6\nn29nNJ5FmEvY2tOjZOZr5VdgmsSZEypi7lwDrDygMelQkrKBdMmGwrshCqD14Qf8\nZNvd1w9iOkGnaKvhf5JQfouKJR33Wi/EBILhdWeAxHZR7YLmmzNX8Ekca2OCBq3v\nyem/KQECgYEA/E2sc16ou/LbejlxmXfmtNoYJVGQnYL4nqgDyodeu/48arMjJvg4\nlYkt1khGqTdPaj1hf5n1bn0+N+6u+R5FjPlyOK0D6apkwK8PPyE2vz2VlJiE72qM\n55RIWnnQ5EfNYld9KNGVsIsx4o9hdZPXLdzeO7NioI02e/iAPqwXQDUCgYEA2uD1\nzC+NKIwPIQZazUWYbKp1q7MY/UpufzMqIJn73layi6Va2Tnn5UNPmrC4XdcLtSmM\nMa+tTlPc8ay+nKiSWzjFCTtsjdSpzMSpN5UbwIJUrMpUFORbkZ8tb82NZrR+iqq7\nolzCAVveFlG8gLMjxz8T7smmV8lMAu6+7NOkO2ECgYBw5CBhjt1ZG5Vw3vshfDDS\ngzOCnzhiAhRUiUEJAgE1hNBrvbPg3/gRkMvdsYFMfd8e3lAd1DmpMokAZeAMv6rH\nJWYiTegOSZvDS5E64hWpBFlFn+j7Z2WcyRCGyzLYsfgIJLVv6jdcQywS/6zP+1Kw\nxr75X46l4Amc9tgLMt1EcQKBgHon0waCA2X9xPPJeCPYE5mSCNoqumeigsi65WgM\niGUuPbdyMaHKj4GEb4kF19+HhSE2bufMBA0TANxgbIFCE2yV4mGkqJD/f0So/Ufo\nD/UAyAEnaoW+bNx42gLr1V7cnUMGxnF3E09u1iPeujWZxP4OVjGOmSelUKbSV/wU\nojQBAoGBAPhq48Wb4RyxnufYy+qIXMvqxyS3BVwyisPHITGyysghXMPfozoJtVVJ\ndq43RlnNURTYGuhYGfHsR3PPKYKrQTXs8OyqpSyruMxE1REMkfo+0H3EPgYpnClH\nRCR0x8kvDwWPpSQFGEiBGzbKDQGYpFOKadrkpHf+lrdYi92lY/uW\n-----END RSA PRIVATE KEY-----\n",
      "xmlsec_certificate" => "-----BEGIN CERTIFICATE-----\nMIIEqjCCA5KgAwIBAgIJANPoN49RcmJ9MA0GCSqGSIb3DQEBBQUAMIGUMQswCQYD\nVQQGEwJVUzEQMA4GA1UECBMHQXJpem9uYTETMBEGA1UEBxMKU2NvdHRzZGFsZTEV\nMBMGA1UEChMMQ2hyb251cyBDb3JwMQ8wDQYDVQQLEwZNZW50b3IxFjAUBgNVBAMU\nDSouY2hyb251cy5jb20xHjAcBgkqhkiG9w0BCQEWD29wc0BjaHJvbnVzLmNvbTAe\nFw0xNTAxMjAwOTE2MDlaFw0yNTAxMTcwOTE2MDlaMIGUMQswCQYDVQQGEwJVUzEQ\nMA4GA1UECBMHQXJpem9uYTETMBEGA1UEBxMKU2NvdHRzZGFsZTEVMBMGA1UEChMM\nQ2hyb251cyBDb3JwMQ8wDQYDVQQLEwZNZW50b3IxFjAUBgNVBAMUDSouY2hyb251\ncy5jb20xHjAcBgkqhkiG9w0BCQEWD29wc0BjaHJvbnVzLmNvbTCCASIwDQYJKoZI\nhvcNAQEBBQADggEPADCCAQoCggEBANe32xC2W7qfg/zeJGg8JYpP0K79HGeBN0CZ\nwJR6xD02yc4xqa0feTlI3/fpQSX9sRPwlfepZu4xiwzwIcC4ZbRD+owP1vukwXCy\n14K29xePOPLQfxbVPAnAZR5+HYdP6aTIZ1rKezhF4PjuMtrbPVZT3qIfgZ1EJMAz\n89Ke76JWsdR0SLKLr6ANrqwuWa/Twuj6r76Y8q2Jk8v+VsihhdGbZcKowbcxHkct\n0/2/c691mZWd9h6b6V3sKN/DQP9LPM4Xyu37LZnn72gXN8IwXZkY9eJczG4Ddg1g\n8w74O9+uYDV4m/1HUnCkxKjCCnN21nnY0RW2quN3ERD5FWGPixUCAwEAAaOB/DCB\n+TAdBgNVHQ4EFgQUwjrOcBBlsKfZKKd+ULhvVe5klscwgckGA1UdIwSBwTCBvoAU\nwjrOcBBlsKfZKKd+ULhvVe5klsehgZqkgZcwgZQxCzAJBgNVBAYTAlVTMRAwDgYD\nVQQIEwdBcml6b25hMRMwEQYDVQQHEwpTY290dHNkYWxlMRUwEwYDVQQKEwxDaHJv\nbnVzIENvcnAxDzANBgNVBAsTBk1lbnRvcjEWMBQGA1UEAxQNKi5jaHJvbnVzLmNv\nbTEeMBwGCSqGSIb3DQEJARYPb3BzQGNocm9udXMuY29tggkA0+g3j1FyYn0wDAYD\nVR0TBAUwAwEB/zANBgkqhkiG9w0BAQUFAAOCAQEA055jMeP+r+TuUvxyz+vp2K3O\nZthUTCfa14zQgENDkUXNpkP/ncPQCzyc5V8e+jxcEmT+WvAsw/5M7fE1il+9ABjT\n8KO7nxjOyWhRpBhZLzdOjldI+cEZeVkg4k0HGoYdUP40rGuhp1xRZXEnjFKjuivb\npAX2gVXt2Kj2hWnrfZOc6bCQ0wmvkYtGaOXsdF32ZJIzO3c3Aod4/zh0aBW7qp1b\nPcmozRp3QbxOxVShfRp6ImWJheWiY0PBOmXP0qs/awZ8xYe38nXCqc7C2rG02Nys\noRl3rt2WIsEX3JifIH3l5HYZnUuwWyA3+bpiPcz8d4bOmn5C/jPntku/Ug+zEQ==\n-----END CERTIFICATE-----\n",
      "friendly_name" => "Saml Previous"
    }
    saml_auth_config = create_saml_auth(org, {}, saml_options)

    current_member_is :f_admin
    current_organization_is org
    get :download_idp_certificate
    assert_response :success
    assert_equal "text/plain", response.content_type
  end
end