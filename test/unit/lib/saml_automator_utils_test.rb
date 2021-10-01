require_relative './../../test_helper.rb'

class SamlAutomatorUtilsTest < ActiveSupport::TestCase

  def test_setup_saml_auth_config
    org = programs(:org_primary)
    stub_saml_sso_files(org.id)
    assert SamlAutomatorUtils.setup_saml_auth_config(org)
    assert org.has_saml_auth?
    saml_settings = org.auth_configs.find_by(auth_type: AuthConfig::Type::SAML).saml_settings

    assert_equal "https://bneadf60.thiess.com.au/adfs/ls/", saml_settings.idp_destination
    assert_equal "https://bneadf60.thiess.com.au/adfs/ls/", saml_settings.idp_sso_target_url
    assert_equal "xmlsec1", saml_settings.xmlsec1_path
    assert_equal org.default_program_domain.get_url, saml_settings.issuer
    assert_nil saml_settings.name_identifier_format
    assert_equal "urn:oasis:names:tc:SAML:2.0:ac:classes:PasswordProtectedTransport", saml_settings.requested_authn_context
    assert_false saml_settings.authn_signed
    assert_equal "I5dm8FNwgAvQc4RFYFt3FA", saml_settings.xmlsec_privatekey_pwd
    assert_equal "MIIE6jCCA9KgAwIBAgIQLLkSkVIf0So/ZD76QYUhujANBgkqhkiG9w0BAQUFADBeMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMVGhhd3RlLCBJbmMuMR0wGwYDVQQLExREb21haW4gVmFsaWRhdGVkIFNTTDEZMBcGA1UEAxMQVGhhd3RlIERWIFNTTCBDQTAeFw0xMjA4MjcwMDAwMDBaFw0xNDA4MjcyMzU5NTlaMIGYMTswOQYDVQQLEzJHbyB0byBodHRwczovL3d3dy50aGF3dGUuY29tL3JlcG9zaXRvcnkvaW5kZXguaHRtbDEiMCAGA1UECxMZVGhhd3RlIFNTTDEyMyBjZXJ0aWZpY2F0ZTEZMBcGA1UECxMQRG9tYWluIFZhbGlkYXRlZDEaMBgGA1UEAxQRb2NhLnRoaWVzcy5jb20uYXUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCuco4tuNa6JaI3S4qBXQNWZprF0zwv8IbSckK3Zzxnmsmre7ZesMtoe9zZ9QNxJAqc0ifSXmzWm2cUerfiZZk6zGpfApJGeZGvq4Rb2MeO7OII7yyUUwUiHcHtQuioGxI097bWrZ6r4rFPWfUAf7ruGJvKw5oIAFRHzgQoQ/Hk29ED1F3wC/iKQYJhPMldsDRXXkpnW+nm5gfp6/lQ8VG59BixEsxDl+mBdRGV8mPwjRj3xrPTuRIOCbkmNJh6+X2AsPv1CReJC1c2yJHiUKzTR40TwnT0YWvPrp6uO1PtdnkaYMPiKLjJFn/kHbw6CHa/6Djnd6+ZdepsDN9lj9RhAgMBAAGjggFnMIIBYzAcBgNVHREEFTATghFvY2EudGhpZXNzLmNvbS5hdTAJBgNVHRMEAjAAMDoGA1UdHwQzMDEwL6AtoCuGKWh0dHA6Ly9zdnItZHYtY3JsLnRoYXd0ZS5jb20vVGhhd3RlRFYuY3JsMEEGA1UdIAQ6MDgwNgYKYIZIAYb4RQEHNjAoMCYGCCsGAQUFBwIBFhpodHRwczovL3d3dy50aGF3dGUuY29tL2NwczAfBgNVHSMEGDAWgBSrRORd7IPH2cCFn/fhxpeQsIw/mDAOBgNVHQ8BAf8EBAMCBaAwHQYDVR0lBBYwFAYIKwYBBQUHAwEGCCsGAQUFBwMCMGkGCCsGAQUFBwEBBF0wWzAiBggrBgEFBQcwAYYWaHR0cDovL29jc3AudGhhd3RlLmNvbTA1BggrBgEFBQcwAoYpaHR0cDovL3N2ci1kdi1haWEudGhhd3RlLmNvbS9UaGF3dGVEVi5jZXIwDQYJKoZIhvcNAQEFBQADggEBAF9udacx+fgHGpL7iikuV8e9LDgrfbt2fd2kfk0WJKhSP9mkGzPHdg9pwvBm6gpx2mkRogoKFVwCrzo4+BJfkucfOZa9Jjw18g8vY7QV/SsxOAwHONOKS8OqNlGPL9J8bEEfXWYO36j1COqZXNaqeuRN94b63AiifFj9R8RRoLTCneTofaoiht+mG5N99wbU7Wfehq/Dn4ECPgvtU1V+XbgfWaAxpzHrWO0Q9qn1hquID3MXXFpt8EMjLKN2YZzwZwcieO/YI0DM7ebq2Pz6Kqo0YfyyH4IgFq7nWhPXAM37kNLFtLotfca0L9aLnnaPLnIxVYIXx0vDxPxwBB5/k4c=", saml_settings.idp_base64_cert
    assert_equal "bcdb6805fcc0498d69ed040d15f83f3bf10d05ca", saml_settings.idp_cert_fingerprint
    assert_equal "-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEAzPVJZw+oqD5w4UOBbYShcYNUutT99wzd/rlT/IM7XHeuZs+c\nZRJyVGmwfYwoDOxhrnGH7Z9unpApYwoD/QQYRX9G2kYtNyplU5Ef8Fzve4vZ0bWx\n7p1e6DPjSIgmyjIeCUZfaNJDuMh4Dd1SzHBE4ZdxRe3JGDDwMRR1H+/XcHYbjWmU\nSAEqqr/yXkIxKBESMmEex4j3gmhSSMypIHn+/3Itm2tSzByJeSP4PPEfIqKPz/ej\n8pRh0YS85BYt7YBoKtVPa95F4OsF27H85Elw47rNluvdzdR43yhvSXmuQ46cqrut\nUN19AmyAp0D8471myIzsMal6QrHzNvEKC/1uXQIDAQABAoIBAGV7poazSC1WDYpc\nZH+XxmBwSMnhoIZtBpaTqTREvmXAlMgvUB7zjUyisFLZzRLpEEzRxh4wbRNyCiwR\nz3u+RU5UAP8e9FB2W4mPOCNJwQKJcqbVsm6V2WJcHtPRJnPDcP/iqmc6hXG/QUKM\nLe0wQcr5s4qOfJ3PzX5fxMa1eRUjYrS/6/d+JWvdNOnLohoniP0DMfrUBJP9X6hH\nsPuuLPSYJuh5S3aVYg9CxR2koWsHqEHIMMVB+NN1lTWBLeXx5Rptu6hFraVb6Tpq\nIzcbDA3AU1u3EwCSWCqtFWYAgkSszWOhqnzfoJRALIA+/8D0FcD6qc+j2x64ZiM/\naqbJjjkCgYEA8rvScP+q2B4aJwRWacuPdeLXJlJtdicp/DGnaGyqwMgoDJHklB2t\nnnpESpfab0B/GmycC02pHuwE7gQ49ERO6KKZCraMWGTADr0+6SGvzbiWi1WHfw8C\nlFVQXyZfZs5ju0Kg6qFzfFJEt/ZYGmBvzgH+n5rrO10+fOpz/sOtNqsCgYEA2Cju\n39Hn3k/ZfjxVLWp5CLfEi/+bmMVmKb2oO5RWvZIlo2AVYSpZE3IUO3SSqcOdefPR\nmLImpkWFi8sIstwMQOgAhBbFXG239DaUSwVnEzv1R1Hkf6E5rOWRcIhqKWAQT0Qr\nX7h4RTqubbIAmW3UkrFQsfX7hZv54oobA/GsjxcCgYBlaa15gofpdWItzPUhjGeq\ntBR5sVSEWcaD1GcCDOymULnSzp12eJPSM3kWxS0A8CxqaNglLNQs1CUXIHJ/M47Y\nSR6xyCUIxUcsoUqIcoeV5roXCqvqnOXR/Xbv2gNf23j1gtfiT4QFfAWz6ltS4dm0\nc0bjfgErs0BpRjciSLS0swKBgFZIgJF3CEcFOJvbGWT3izifoiT/8uwYX59pxS2D\nGNyy6bM9N0uBy+ynLMxOy/xXyRRU7uU0t5jHR3d1pBNBIuMFuK8BJ+atJTCmWKtZ\njLtww4ekeME5afxJ5rQ0v6ukXN5HJ8kdqWR4+AdxdivIW4HypXNj7PJ4QFbdKct5\nPJghAoGBAL7SkHK8WWVLDLzgZ/28i2nPdZnlLzeVnAwYipIfX4zIsWEcoricIEsH\nLBraY6urr6uhI1deHOY/qkb/zsHYRKuD/4xGuZXh9kt1UKFcvZk5Cxy2N7U8W1HH\nfsSmFyqX3NAhE+GgJKU3XE+ljzQfIA5W1bMCXW9fjjAe+201tOh/\n-----END RSA PRIVATE KEY-----\n", saml_settings.xmlsec_privatekey
    assert_equal "-----BEGIN CERTIFICATE-----\nMIIDpjCCAo4CCQCycttVqk/QbTANBgkqhkiG9w0BAQUFADCBlDELMAkGA1UEBhMC\nVVMxEDAOBgNVBAgTB0FyaXpvbmExEzARBgNVBAcTClNjb3R0c2RhbGUxFTATBgNV\nBAoTDENocm9udXMgQ29ycDEPMA0GA1UECxMGTWVudG9yMRYwFAYDVQQDFA0qLmNo\ncm9udXMuY29tMR4wHAYJKoZIhvcNAQkBFg9vcHNAY2hyb251cy5jb20wHhcNMTQw\nOTI1MDcwNDMzWhcNMjQwOTIyMDcwNDMzWjCBlDELMAkGA1UEBhMCVVMxEDAOBgNV\nBAgTB0FyaXpvbmExEzARBgNVBAcTClNjb3R0c2RhbGUxFTATBgNVBAoTDENocm9u\ndXMgQ29ycDEPMA0GA1UECxMGTWVudG9yMRYwFAYDVQQDFA0qLmNocm9udXMuY29t\nMR4wHAYJKoZIhvcNAQkBFg9vcHNAY2hyb251cy5jb20wggEiMA0GCSqGSIb3DQEB\nAQUAA4IBDwAwggEKAoIBAQDM9UlnD6ioPnDhQ4FthKFxg1S61P33DN3+uVP8gztc\nd65mz5xlEnJUabB9jCgM7GGucYftn26ekCljCgP9BBhFf0baRi03KmVTkR/wXO97\ni9nRtbHunV7oM+NIiCbKMh4JRl9o0kO4yHgN3VLMcEThl3FF7ckYMPAxFHUf79dw\ndhuNaZRIASqqv/JeQjEoERIyYR7HiPeCaFJIzKkgef7/ci2ba1LMHIl5I/g88R8i\noo/P96PylGHRhLzkFi3tgGgq1U9r3kXg6wXbsfzkSXDjus2W693N1HjfKG9Jea5D\njpyqu61Q3X0CbICnQPzjvWbIjOwxqXpCsfM28QoL/W5dAgMBAAEwDQYJKoZIhvcN\nAQEFBQADggEBABKOI4cp6Q9k+rOtr6uK79PfHbXY2EOPtblJa9cWq5basUW6r+F+\nI6pJy1dRXRx02W609vcFOqhH+F/Lzp8rhk5sYmBZ3nXPY9aRxOwgzZqjNn+WQS/e\nKf4zvT8AdLRI5mPNLSZrEQpUQlLuvlY2YfB6JKO/Iv00NiEabAEBfLGZyCNKdwVb\nPbcbGzfMU8jD0fX1drgolsqtSk/ZFEF1g/+b0e3NpFkxxVZq/LBG1i0sjeZ/SbqW\n4XTha46OieEBOfHEV73hHIAzMcOxwmqmcKqBtz7CgLeo6hgXSyy17sVShAVQzykf\n85+3UmRABRchQRanNT4n8TdjJZdav/Wi+qs=\n-----END CERTIFICATE-----\n", saml_settings.xmlsec_certificate
  end

  def test_setup_saml_auth_config_update_certificate
    org = programs(:org_primary)
    stub_saml_sso_files(org.id)
    assert SamlAutomatorUtils.setup_saml_auth_config(org, update_certificate_only: true)
    assert org.has_saml_auth?
    saml_settings = org.auth_configs.find_by(auth_type: AuthConfig::Type::SAML).saml_settings

    assert_nil saml_settings.idp_destination
    assert_nil saml_settings.idp_sso_target_url
    assert_equal "xmlsec1", saml_settings.xmlsec1_path
    assert_nil saml_settings.name_identifier_format
    assert_equal "urn:oasis:names:tc:SAML:2.0:ac:classes:PasswordProtectedTransport", saml_settings.requested_authn_context
    assert_false saml_settings.authn_signed
    assert_nil saml_settings.xmlsec_privatekey_pwd
    assert_equal "MIIE6jCCA9KgAwIBAgIQLLkSkVIf0So/ZD76QYUhujANBgkqhkiG9w0BAQUFADBeMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMVGhhd3RlLCBJbmMuMR0wGwYDVQQLExREb21haW4gVmFsaWRhdGVkIFNTTDEZMBcGA1UEAxMQVGhhd3RlIERWIFNTTCBDQTAeFw0xMjA4MjcwMDAwMDBaFw0xNDA4MjcyMzU5NTlaMIGYMTswOQYDVQQLEzJHbyB0byBodHRwczovL3d3dy50aGF3dGUuY29tL3JlcG9zaXRvcnkvaW5kZXguaHRtbDEiMCAGA1UECxMZVGhhd3RlIFNTTDEyMyBjZXJ0aWZpY2F0ZTEZMBcGA1UECxMQRG9tYWluIFZhbGlkYXRlZDEaMBgGA1UEAxQRb2NhLnRoaWVzcy5jb20uYXUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCuco4tuNa6JaI3S4qBXQNWZprF0zwv8IbSckK3Zzxnmsmre7ZesMtoe9zZ9QNxJAqc0ifSXmzWm2cUerfiZZk6zGpfApJGeZGvq4Rb2MeO7OII7yyUUwUiHcHtQuioGxI097bWrZ6r4rFPWfUAf7ruGJvKw5oIAFRHzgQoQ/Hk29ED1F3wC/iKQYJhPMldsDRXXkpnW+nm5gfp6/lQ8VG59BixEsxDl+mBdRGV8mPwjRj3xrPTuRIOCbkmNJh6+X2AsPv1CReJC1c2yJHiUKzTR40TwnT0YWvPrp6uO1PtdnkaYMPiKLjJFn/kHbw6CHa/6Djnd6+ZdepsDN9lj9RhAgMBAAGjggFnMIIBYzAcBgNVHREEFTATghFvY2EudGhpZXNzLmNvbS5hdTAJBgNVHRMEAjAAMDoGA1UdHwQzMDEwL6AtoCuGKWh0dHA6Ly9zdnItZHYtY3JsLnRoYXd0ZS5jb20vVGhhd3RlRFYuY3JsMEEGA1UdIAQ6MDgwNgYKYIZIAYb4RQEHNjAoMCYGCCsGAQUFBwIBFhpodHRwczovL3d3dy50aGF3dGUuY29tL2NwczAfBgNVHSMEGDAWgBSrRORd7IPH2cCFn/fhxpeQsIw/mDAOBgNVHQ8BAf8EBAMCBaAwHQYDVR0lBBYwFAYIKwYBBQUHAwEGCCsGAQUFBwMCMGkGCCsGAQUFBwEBBF0wWzAiBggrBgEFBQcwAYYWaHR0cDovL29jc3AudGhhd3RlLmNvbTA1BggrBgEFBQcwAoYpaHR0cDovL3N2ci1kdi1haWEudGhhd3RlLmNvbS9UaGF3dGVEVi5jZXIwDQYJKoZIhvcNAQEFBQADggEBAF9udacx+fgHGpL7iikuV8e9LDgrfbt2fd2kfk0WJKhSP9mkGzPHdg9pwvBm6gpx2mkRogoKFVwCrzo4+BJfkucfOZa9Jjw18g8vY7QV/SsxOAwHONOKS8OqNlGPL9J8bEEfXWYO36j1COqZXNaqeuRN94b63AiifFj9R8RRoLTCneTofaoiht+mG5N99wbU7Wfehq/Dn4ECPgvtU1V+XbgfWaAxpzHrWO0Q9qn1hquID3MXXFpt8EMjLKN2YZzwZwcieO/YI0DM7ebq2Pz6Kqo0YfyyH4IgFq7nWhPXAM37kNLFtLotfca0L9aLnnaPLnIxVYIXx0vDxPxwBB5/k4c=", saml_settings.idp_base64_cert
    assert_equal "bcdb6805fcc0498d69ed040d15f83f3bf10d05ca", saml_settings.idp_cert_fingerprint
    assert_nil saml_settings.xmlsec_privatekey
    assert_nil saml_settings.xmlsec_certificate
  end

  def test_setup_saml_auth_config_is_atomic
    org = programs(:org_primary)
    stub_saml_sso_files(org.id)
    assert_no_difference "AuthConfig.count" do
      SamlAutomatorUtils.stubs(:get_saml_options).raises(RuntimeError, "Invalid certificate")
      assert_false SamlAutomatorUtils.setup_saml_auth_config(org)
    end
  end

  def test_get_basepath
    Timecop.freeze do
      current_utc_timestamp = Time.now.utc.strftime('%Y%m%d%H%M%S')
      basepath = SamlAutomatorUtils::SamlFileUtils.get_basepath
      assert_equal current_utc_timestamp, File.basename(basepath)
      assert_equal "#{Rails.root}/tmp", File.dirname(basepath)
    end
  end

  def test_get_files_from_s3
    org = programs(:org_primary)
    mock_s3_objects
    SamlAutomatorUtils::RegexPatterns.constants.each do |constant|
      file_regex = SamlAutomatorUtils::RegexPatterns.const_get(constant)
      objects = SamlAutomatorUtils::SamlFileUtils.get_files_from_s3(org.id, file_regex)
      assert_equal 1, objects.size
      assert file_regex.match(objects[0].key)
    end
  end

  def test_get_latest_file_from_s3
    org = programs(:org_primary)
    Timecop.freeze do
      timestamp_now = Time.now.utc.strftime('%Y%m%d%H%M%S')
      mock_s3_objects(except_idp_metadata: true, except_passphrase: true, except_cert: true, except_key: true)
      object = SamlAutomatorUtils::SamlFileUtils.get_latest_file_from_s3(org.id, SamlAutomatorUtils::RegexPatterns::SP_METADATA_FILE)
      assert object.key.match(timestamp_now)
      assert object.key.match(SamlAutomatorUtils::RegexPatterns::SP_METADATA_FILE)

      sp_metadata_1 = mock()
      sp_metadata_1.stubs(:key).returns("#{timestamp_now}_SP_Metadata.xml")
      timestamp_next_day = (Time.now.utc + 1.day).strftime('%Y%m%d%H%M%S')
      sp_metadata_2 = mock()
      sp_metadata_2.stubs(:key).returns("#{timestamp_next_day}_SP_Metadata.xml")
      S3Helper.expects(:get_objects_with_prefix).returns([sp_metadata_1, sp_metadata_2]).at_least(0)
      object = SamlAutomatorUtils::SamlFileUtils.get_latest_file_from_s3(org.id, SamlAutomatorUtils::RegexPatterns::SP_METADATA_FILE)
      assert_nil object.key.match(timestamp_now)
      assert object.key.match(timestamp_next_day) # Latest file
      assert object.key.match(SamlAutomatorUtils::RegexPatterns::SP_METADATA_FILE)
    end
  end

  def test_check_if_files_present_in_s3
    org = programs(:org_primary)
    mock_s3_objects
    file_regexes = [SamlAutomatorUtils::RegexPatterns::SP_METADATA_FILE, SamlAutomatorUtils::RegexPatterns::IDP_METADATA_FILE, SamlAutomatorUtils::RegexPatterns::PASSPHRASE_FILE, SamlAutomatorUtils::RegexPatterns::CERT_FILE, SamlAutomatorUtils::RegexPatterns::KEY_FILE]
    assert SamlAutomatorUtils::SamlFileUtils.check_if_files_present_in_s3(org.id, file_regexes)

    mock_s3_objects(except_sp_metadata: true)
    assert_false SamlAutomatorUtils::SamlFileUtils.check_if_files_present_in_s3(org.id, file_regexes)
    assert SamlAutomatorUtils::SamlFileUtils.check_if_files_present_in_s3(org.id, file_regexes - [SamlAutomatorUtils::RegexPatterns::SP_METADATA_FILE])
  end

  def test_write_file_to_local
    source_file = mock()
    file = fixture_file_upload(File.join('files', 'test_utf8.txt'), 'text/text', true)
    source_file.stubs(:key).returns("s3_file")
    source_file.stubs(:read).returns(file.read)
    local_file = SamlAutomatorUtils::SamlFileUtils.write_file_to_local(source_file)
    assert_match /.*Using Unicode.*/, File.read(local_file)
    source_file.stubs(:original_filename).returns("uploaded_file")
    source_file.stubs(:read).returns("Uploaded file")
    local_file = SamlAutomatorUtils::SamlFileUtils.write_file_to_local(source_file, s3_file: false)
    assert_equal "Uploaded file", File.read(local_file)
  end

  def test_copy_file_from_s3
    org = programs(:org_primary)
    source_files = s3_objects(except_idp_metadata: true, except_passphrase: true, except_cert: true, except_key: true)
    source_files[0].stubs(:read).returns("S3 file")
    S3Helper.expects(:get_objects_with_prefix).returns(source_files).at_least(0)
    local_file = SamlAutomatorUtils::SamlFileUtils.copy_file_from_s3(org.id, SamlAutomatorUtils::RegexPatterns::SP_METADATA_FILE)
    assert_equal "S3 file", File.read(local_file)
  end

  def test_get_saml_files_from_s3
    sp_metadata, idp_metadata, passphrase, cert, key = s3_objects
    idp_metadata.stubs(:read).returns("idp_metadata")
    passphrase.stubs(:read).returns("passphrase")
    cert.stubs(:read).returns("cert")
    key.stubs(:read).returns("key")
    objects = [idp_metadata, passphrase, cert, key]
    S3Helper.expects(:get_objects_with_prefix).returns(objects).at_least(0)
    files = SamlAutomatorUtils::SamlFileUtils.get_saml_files_from_s3(programs(:org_primary).id)
    assert_equal "idp_metadata", File.read(files[:idp_metadata][:path])
    assert_equal "passphrase", File.read(files[:passphrase][:path])
    assert_equal "cert", File.read(files[:cert][:path])
    assert_equal "key", File.read(files[:key][:path])
  end

  def test_transfer_files_to_s3
    org_id = programs(:org_primary).id
    basepath = SamlAutomatorUtils::SamlFileUtils.get_basepath
    passphrase_file = "#{basepath}_passphrase"
    cert_file = "#{basepath}_cert.pem"
    key_file = "#{basepath}_key.pem"
    sp_metadata_file = "#{basepath}_SP_Metadata.xml"
    files_to_transfer = [[passphrase_file, "text/plain"], [cert_file, "text/plain"], [key_file, "text/plain"], [sp_metadata_file, "application/xml"]]
    files_to_transfer.each do |file, content_type|
      S3Helper.expects(:transfer).with(file, "#{SAML_SSO_DIR}/#{org_id}", APP_CONFIG[:chronus_mentor_common_bucket], { url_expires: 7.days, content_type: content_type, discard_source: false })
    end
    SamlAutomatorUtils::SamlFileUtils.transfer_files_to_s3(files_to_transfer, org_id)
  end

  def test_generate_sp_metadata_file
    Timecop.freeze do
      basepath = SamlAutomatorUtils::SamlFileUtils.get_basepath
      timestamp = basepath.split("/").last
      S3Helper.expects(:transfer).times(4)
      SamlAutomatorUtils.expects(:generate_passphrase).once
      SamlAutomatorUtils.expects(:generate_private_key_and_cert).once
      SamlAutomatorUtils.expects(:generate_metadata_xml).once

      assert_equal "#{basepath}/#{timestamp}_SP_Metadata.xml", SamlAutomatorUtils.generate_sp_metadata_file(programs(:org_primary))
    end
  end

  def test_get_encoded_cert_content_and_fingerprint
    cert_text = File.read(File.join(Rails.root, "test", "fixtures", "files", "saml_sso", "20140925070427_cert.pem"))
    encoded_content, fingerprint = SamlAutomatorUtils.get_encoded_cert_content_and_fingerprint(cert_text.gsub(/\w*-+(BEGIN|END) CERTIFICATE-+\w*/, "").gsub("\r\n", "").strip)
    assert_equal cert_text.gsub(/\w*-+(BEGIN|END) CERTIFICATE-+\w*/, "").gsub("\r\n", "").strip, encoded_content
    assert_equal "bb1892e7f8a23ebcce0cfe5c3045ec3dabadcf3f", fingerprint
  end

  def test_get_encoded_cert_text
    idp_metadata = File.read(File.join(Rails.root, "test", "fixtures", "files", "saml_sso", "20140925070519_IDP_Metadata.xml"))
    cert_content = SamlAutomatorUtils.get_encoded_cert_text_from_metadata(idp_metadata)
    assert_equal "MIIE6jCCA9KgAwIBAgIQLLkSkVIf0So/ZD76QYUhujANBgkqhkiG9w0BAQUFADBeMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMVGhhd3RlLCBJbmMuMR0wGwYDVQQLExREb21haW4gVmFsaWRhdGVkIFNTTDEZMBcGA1UEAxMQVGhhd3RlIERWIFNTTCBDQTAeFw0xMjA4MjcwMDAwMDBaFw0xNDA4MjcyMzU5NTlaMIGYMTswOQYDVQQLEzJHbyB0byBodHRwczovL3d3dy50aGF3dGUuY29tL3JlcG9zaXRvcnkvaW5kZXguaHRtbDEiMCAGA1UECxMZVGhhd3RlIFNTTDEyMyBjZXJ0aWZpY2F0ZTEZMBcGA1UECxMQRG9tYWluIFZhbGlkYXRlZDEaMBgGA1UEAxQRb2NhLnRoaWVzcy5jb20uYXUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCuco4tuNa6JaI3S4qBXQNWZprF0zwv8IbSckK3Zzxnmsmre7ZesMtoe9zZ9QNxJAqc0ifSXmzWm2cUerfiZZk6zGpfApJGeZGvq4Rb2MeO7OII7yyUUwUiHcHtQuioGxI097bWrZ6r4rFPWfUAf7ruGJvKw5oIAFRHzgQoQ/Hk29ED1F3wC/iKQYJhPMldsDRXXkpnW+nm5gfp6/lQ8VG59BixEsxDl+mBdRGV8mPwjRj3xrPTuRIOCbkmNJh6+X2AsPv1CReJC1c2yJHiUKzTR40TwnT0YWvPrp6uO1PtdnkaYMPiKLjJFn/kHbw6CHa/6Djnd6+ZdepsDN9lj9RhAgMBAAGjggFnMIIBYzAcBgNVHREEFTATghFvY2EudGhpZXNzLmNvbS5hdTAJBgNVHRMEAjAAMDoGA1UdHwQzMDEwL6AtoCuGKWh0dHA6Ly9zdnItZHYtY3JsLnRoYXd0ZS5jb20vVGhhd3RlRFYuY3JsMEEGA1UdIAQ6MDgwNgYKYIZIAYb4RQEHNjAoMCYGCCsGAQUFBwIBFhpodHRwczovL3d3dy50aGF3dGUuY29tL2NwczAfBgNVHSMEGDAWgBSrRORd7IPH2cCFn/fhxpeQsIw/mDAOBgNVHQ8BAf8EBAMCBaAwHQYDVR0lBBYwFAYIKwYBBQUHAwEGCCsGAQUFBwMCMGkGCCsGAQUFBwEBBF0wWzAiBggrBgEFBQcwAYYWaHR0cDovL29jc3AudGhhd3RlLmNvbTA1BggrBgEFBQcwAoYpaHR0cDovL3N2ci1kdi1haWEudGhhd3RlLmNvbS9UaGF3dGVEVi5jZXIwDQYJKoZIhvcNAQEFBQADggEBAF9udacx+fgHGpL7iikuV8e9LDgrfbt2fd2kfk0WJKhSP9mkGzPHdg9pwvBm6gpx2mkRogoKFVwCrzo4+BJfkucfOZa9Jjw18g8vY7QV/SsxOAwHONOKS8OqNlGPL9J8bEEfXWYO36j1COqZXNaqeuRN94b63AiifFj9R8RRoLTCneTofaoiht+mG5N99wbU7Wfehq/Dn4ECPgvtU1V+XbgfWaAxpzHrWO0Q9qn1hquID3MXXFpt8EMjLKN2YZzwZwcieO/YI0DM7ebq2Pz6Kqo0YfyyH4IgFq7nWhPXAM37kNLFtLotfca0L9aLnnaPLnIxVYIXx0vDxPxwBB5/k4c=", cert_content
  end

  def test_get_saml_options
    org = programs(:org_primary)
    stub_saml_sso_files(org.id)
    SamlAutomatorUtils.stubs(:get_sso_target_url).returns("https://abcd.com")
    saml_files = SamlAutomatorUtils::SamlFileUtils.get_saml_files_from_s3(org.id)
    saml_options = SamlAutomatorUtils.get_saml_options(org, saml_files, idp_metadata: File.join(Rails.root, "test", "fixtures", "files", "saml_sso", "20140925070519_IDP_Metadata.xml"))

    assert_equal "https://abcd.com", saml_options["idp_destination"]
    assert_equal "https://abcd.com", saml_options["idp_sso_target_url"]
    assert_equal "-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEAzPVJZw+oqD5w4UOBbYShcYNUutT99wzd/rlT/IM7XHeuZs+c\nZRJyVGmwfYwoDOxhrnGH7Z9unpApYwoD/QQYRX9G2kYtNyplU5Ef8Fzve4vZ0bWx\n7p1e6DPjSIgmyjIeCUZfaNJDuMh4Dd1SzHBE4ZdxRe3JGDDwMRR1H+/XcHYbjWmU\nSAEqqr/yXkIxKBESMmEex4j3gmhSSMypIHn+/3Itm2tSzByJeSP4PPEfIqKPz/ej\n8pRh0YS85BYt7YBoKtVPa95F4OsF27H85Elw47rNluvdzdR43yhvSXmuQ46cqrut\nUN19AmyAp0D8471myIzsMal6QrHzNvEKC/1uXQIDAQABAoIBAGV7poazSC1WDYpc\nZH+XxmBwSMnhoIZtBpaTqTREvmXAlMgvUB7zjUyisFLZzRLpEEzRxh4wbRNyCiwR\nz3u+RU5UAP8e9FB2W4mPOCNJwQKJcqbVsm6V2WJcHtPRJnPDcP/iqmc6hXG/QUKM\nLe0wQcr5s4qOfJ3PzX5fxMa1eRUjYrS/6/d+JWvdNOnLohoniP0DMfrUBJP9X6hH\nsPuuLPSYJuh5S3aVYg9CxR2koWsHqEHIMMVB+NN1lTWBLeXx5Rptu6hFraVb6Tpq\nIzcbDA3AU1u3EwCSWCqtFWYAgkSszWOhqnzfoJRALIA+/8D0FcD6qc+j2x64ZiM/\naqbJjjkCgYEA8rvScP+q2B4aJwRWacuPdeLXJlJtdicp/DGnaGyqwMgoDJHklB2t\nnnpESpfab0B/GmycC02pHuwE7gQ49ERO6KKZCraMWGTADr0+6SGvzbiWi1WHfw8C\nlFVQXyZfZs5ju0Kg6qFzfFJEt/ZYGmBvzgH+n5rrO10+fOpz/sOtNqsCgYEA2Cju\n39Hn3k/ZfjxVLWp5CLfEi/+bmMVmKb2oO5RWvZIlo2AVYSpZE3IUO3SSqcOdefPR\nmLImpkWFi8sIstwMQOgAhBbFXG239DaUSwVnEzv1R1Hkf6E5rOWRcIhqKWAQT0Qr\nX7h4RTqubbIAmW3UkrFQsfX7hZv54oobA/GsjxcCgYBlaa15gofpdWItzPUhjGeq\ntBR5sVSEWcaD1GcCDOymULnSzp12eJPSM3kWxS0A8CxqaNglLNQs1CUXIHJ/M47Y\nSR6xyCUIxUcsoUqIcoeV5roXCqvqnOXR/Xbv2gNf23j1gtfiT4QFfAWz6ltS4dm0\nc0bjfgErs0BpRjciSLS0swKBgFZIgJF3CEcFOJvbGWT3izifoiT/8uwYX59pxS2D\nGNyy6bM9N0uBy+ynLMxOy/xXyRRU7uU0t5jHR3d1pBNBIuMFuK8BJ+atJTCmWKtZ\njLtww4ekeME5afxJ5rQ0v6ukXN5HJ8kdqWR4+AdxdivIW4HypXNj7PJ4QFbdKct5\nPJghAoGBAL7SkHK8WWVLDLzgZ/28i2nPdZnlLzeVnAwYipIfX4zIsWEcoricIEsH\nLBraY6urr6uhI1deHOY/qkb/zsHYRKuD/4xGuZXh9kt1UKFcvZk5Cxy2N7U8W1HH\nfsSmFyqX3NAhE+GgJKU3XE+ljzQfIA5W1bMCXW9fjjAe+201tOh/\n-----END RSA PRIVATE KEY-----\n", saml_options["xmlsec_privatekey"]
    assert_equal "-----BEGIN CERTIFICATE-----\nMIIDpjCCAo4CCQCycttVqk/QbTANBgkqhkiG9w0BAQUFADCBlDELMAkGA1UEBhMC\nVVMxEDAOBgNVBAgTB0FyaXpvbmExEzARBgNVBAcTClNjb3R0c2RhbGUxFTATBgNV\nBAoTDENocm9udXMgQ29ycDEPMA0GA1UECxMGTWVudG9yMRYwFAYDVQQDFA0qLmNo\ncm9udXMuY29tMR4wHAYJKoZIhvcNAQkBFg9vcHNAY2hyb251cy5jb20wHhcNMTQw\nOTI1MDcwNDMzWhcNMjQwOTIyMDcwNDMzWjCBlDELMAkGA1UEBhMCVVMxEDAOBgNV\nBAgTB0FyaXpvbmExEzARBgNVBAcTClNjb3R0c2RhbGUxFTATBgNVBAoTDENocm9u\ndXMgQ29ycDEPMA0GA1UECxMGTWVudG9yMRYwFAYDVQQDFA0qLmNocm9udXMuY29t\nMR4wHAYJKoZIhvcNAQkBFg9vcHNAY2hyb251cy5jb20wggEiMA0GCSqGSIb3DQEB\nAQUAA4IBDwAwggEKAoIBAQDM9UlnD6ioPnDhQ4FthKFxg1S61P33DN3+uVP8gztc\nd65mz5xlEnJUabB9jCgM7GGucYftn26ekCljCgP9BBhFf0baRi03KmVTkR/wXO97\ni9nRtbHunV7oM+NIiCbKMh4JRl9o0kO4yHgN3VLMcEThl3FF7ckYMPAxFHUf79dw\ndhuNaZRIASqqv/JeQjEoERIyYR7HiPeCaFJIzKkgef7/ci2ba1LMHIl5I/g88R8i\noo/P96PylGHRhLzkFi3tgGgq1U9r3kXg6wXbsfzkSXDjus2W693N1HjfKG9Jea5D\njpyqu61Q3X0CbICnQPzjvWbIjOwxqXpCsfM28QoL/W5dAgMBAAEwDQYJKoZIhvcN\nAQEFBQADggEBABKOI4cp6Q9k+rOtr6uK79PfHbXY2EOPtblJa9cWq5basUW6r+F+\nI6pJy1dRXRx02W609vcFOqhH+F/Lzp8rhk5sYmBZ3nXPY9aRxOwgzZqjNn+WQS/e\nKf4zvT8AdLRI5mPNLSZrEQpUQlLuvlY2YfB6JKO/Iv00NiEabAEBfLGZyCNKdwVb\nPbcbGzfMU8jD0fX1drgolsqtSk/ZFEF1g/+b0e3NpFkxxVZq/LBG1i0sjeZ/SbqW\n4XTha46OieEBOfHEV73hHIAzMcOxwmqmcKqBtz7CgLeo6hgXSyy17sVShAVQzykf\n85+3UmRABRchQRanNT4n8TdjJZdav/Wi+qs=\n-----END CERTIFICATE-----\n", saml_options["xmlsec_certificate"]
    assert_equal "I5dm8FNwgAvQc4RFYFt3FA", saml_options["xmlsec_privatekey_pwd"]
    assert_equal org.url, saml_options["issuer"]
  end

  def test_get_saml_options_update_certificate_only_from_metadata
    org = programs(:org_primary)
    org.auth_configs.create!(auth_type: AuthConfig::Type::SAML)
    saml_auth = org.saml_auth
    saml_options = {}
    saml_options["idp_destination"] = saml_options["idp_sso_target_url"] = "https://abcd.com"
    saml_options["xmlsec_privatekey"] = "-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEAzPVJZw+oqD5w4UOBbYShcYNUutT99wzd/rlT/IM7XHeuZs+c\nZRJyVGmwfYwoDOxhrnGH7Z9unpApYwoD/QQYRX9G2kYtNyplU5Ef8Fzve4vZ0bWx\n7p1e6DPjSIgmyjIeCUZfaNJDuMh4Dd1SzHBE4ZdxRe3JGDDwMRR1H+/XcHYbjWmU\nSAEqqr/yXkIxKBESMmEex4j3gmhSSMypIHn+/3Itm2tSzByJeSP4PPEfIqKPz/ej\n8pRh0YS85BYt7YBoKtVPa95F4OsF27H85Elw47rNluvdzdR43yhvSXmuQ46cqrut\nUN19AmyAp0D8471myIzsMal6QrHzNvEKC/1uXQIDAQABAoIBAGV7poazSC1WDYpc\nZH+XxmBwSMnhoIZtBpaTqTREvmXAlMgvUB7zjUyisFLZzRLpEEzRxh4wbRNyCiwR\nz3u+RU5UAP8e9FB2W4mPOCNJwQKJcqbVsm6V2WJcHtPRJnPDcP/iqmc6hXG/QUKM\nLe0wQcr5s4qOfJ3PzX5fxMa1eRUjYrS/6/d+JWvdNOnLohoniP0DMfrUBJP9X6hH\nsPuuLPSYJuh5S3aVYg9CxR2koWsHqEHIMMVB+NN1lTWBLeXx5Rptu6hFraVb6Tpq\nIzcbDA3AU1u3EwCSWCqtFWYAgkSszWOhqnzfoJRALIA+/8D0FcD6qc+j2x64ZiM/\naqbJjjkCgYEA8rvScP+q2B4aJwRWacuPdeLXJlJtdicp/DGnaGyqwMgoDJHklB2t\nnnpESpfab0B/GmycC02pHuwE7gQ49ERO6KKZCraMWGTADr0+6SGvzbiWi1WHfw8C\nlFVQXyZfZs5ju0Kg6qFzfFJEt/ZYGmBvzgH+n5rrO10+fOpz/sOtNqsCgYEA2Cju\n39Hn3k/ZfjxVLWp5CLfEi/+bmMVmKb2oO5RWvZIlo2AVYSpZE3IUO3SSqcOdefPR\nmLImpkWFi8sIstwMQOgAhBbFXG239DaUSwVnEzv1R1Hkf6E5rOWRcIhqKWAQT0Qr\nX7h4RTqubbIAmW3UkrFQsfX7hZv54oobA/GsjxcCgYBlaa15gofpdWItzPUhjGeq\ntBR5sVSEWcaD1GcCDOymULnSzp12eJPSM3kWxS0A8CxqaNglLNQs1CUXIHJ/M47Y\nSR6xyCUIxUcsoUqIcoeV5roXCqvqnOXR/Xbv2gNf23j1gtfiT4QFfAWz6ltS4dm0\nc0bjfgErs0BpRjciSLS0swKBgFZIgJF3CEcFOJvbGWT3izifoiT/8uwYX59pxS2D\nGNyy6bM9N0uBy+ynLMxOy/xXyRRU7uU0t5jHR3d1pBNBIuMFuK8BJ+atJTCmWKtZ\njLtww4ekeME5afxJ5rQ0v6ukXN5HJ8kdqWR4+AdxdivIW4HypXNj7PJ4QFbdKct5\nPJghAoGBAL7SkHK8WWVLDLzgZ/28i2nPdZnlLzeVnAwYipIfX4zIsWEcoricIEsH\nLBraY6urr6uhI1deHOY/qkb/zsHYRKuD/4xGuZXh9kt1UKFcvZk5Cxy2N7U8W1HH\nfsSmFyqX3NAhE+GgJKU3XE+ljzQfIA5W1bMCXW9fjjAe+201tOh/\n-----END RSA PRIVATE KEY-----\n"
    saml_options["xmlsec_certificate"] = "-----BEGIN CERTIFICATE-----\nMIIDpjCCAo4CCQCycttVqk/QbTANBgkqhkiG9w0BAQUFADCBlDELMAkGA1UEBhMC\nVVMxEDAOBgNVBAgTB0FyaXpvbmExEzARBgNVBAcTClNjb3R0c2RhbGUxFTATBgNV\nBAoTDENocm9udXMgQ29ycDEPMA0GA1UECxMGTWVudG9yMRYwFAYDVQQDFA0qLmNo\ncm9udXMuY29tMR4wHAYJKoZIhvcNAQkBFg9vcHNAY2hyb251cy5jb20wHhcNMTQw\nOTI1MDcwNDMzWhcNMjQwOTIyMDcwNDMzWjCBlDELMAkGA1UEBhMCVVMxEDAOBgNV\nBAgTB0FyaXpvbmExEzARBgNVBAcTClNjb3R0c2RhbGUxFTATBgNVBAoTDENocm9u\ndXMgQ29ycDEPMA0GA1UECxMGTWVudG9yMRYwFAYDVQQDFA0qLmNocm9udXMuY29t\nMR4wHAYJKoZIhvcNAQkBFg9vcHNAY2hyb251cy5jb20wggEiMA0GCSqGSIb3DQEB\nAQUAA4IBDwAwggEKAoIBAQDM9UlnD6ioPnDhQ4FthKFxg1S61P33DN3+uVP8gztc\nd65mz5xlEnJUabB9jCgM7GGucYftn26ekCljCgP9BBhFf0baRi03KmVTkR/wXO97\ni9nRtbHunV7oM+NIiCbKMh4JRl9o0kO4yHgN3VLMcEThl3FF7ckYMPAxFHUf79dw\ndhuNaZRIASqqv/JeQjEoERIyYR7HiPeCaFJIzKkgef7/ci2ba1LMHIl5I/g88R8i\noo/P96PylGHRhLzkFi3tgGgq1U9r3kXg6wXbsfzkSXDjus2W693N1HjfKG9Jea5D\njpyqu61Q3X0CbICnQPzjvWbIjOwxqXpCsfM28QoL/W5dAgMBAAEwDQYJKoZIhvcN\nAQEFBQADggEBABKOI4cp6Q9k+rOtr6uK79PfHbXY2EOPtblJa9cWq5basUW6r+F+\nI6pJy1dRXRx02W609vcFOqhH+F/Lzp8rhk5sYmBZ3nXPY9aRxOwgzZqjNn+WQS/e\nKf4zvT8AdLRI5mPNLSZrEQpUQlLuvlY2YfB6JKO/Iv00NiEabAEBfLGZyCNKdwVb\nPbcbGzfMU8jD0fX1drgolsqtSk/ZFEF1g/+b0e3NpFkxxVZq/LBG1i0sjeZ/SbqW\n4XTha46OieEBOfHEV73hHIAzMcOxwmqmcKqBtz7CgLeo6hgXSyy17sVShAVQzykf\n85+3UmRABRchQRanNT4n8TdjJZdav/Wi+qs=\n-----END CERTIFICATE-----\n"
    saml_options["xmlsec_privatekey_pwd"] = "I5dm8FNwgAvQc4RFYFt3FA"
    saml_options["issuer"] = org.url
    saml_options["idp_cert_fingerprint"] = "81fe8bfe87576c3ecb22426f8e57847382917acf"
    saml_auth.set_options!(saml_options)
    stub_saml_sso_files(org.id)
    SamlAutomatorUtils.stubs(:get_sso_target_url).returns("https://abcd.com")
    saml_files = SamlAutomatorUtils::SamlFileUtils.get_saml_files_from_s3(org.id)
    saml_options = SamlAutomatorUtils.get_saml_options(org, saml_files, idp_metadata: File.join(Rails.root, "test", "fixtures", "files", "saml_sso", "20140925070519_IDP_Metadata.xml"), update_certificate_only: true)

    assert_equal "https://abcd.com", saml_options["idp_destination"]
    assert_equal "https://abcd.com", saml_options["idp_sso_target_url"]
    assert_equal "-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEAzPVJZw+oqD5w4UOBbYShcYNUutT99wzd/rlT/IM7XHeuZs+c\nZRJyVGmwfYwoDOxhrnGH7Z9unpApYwoD/QQYRX9G2kYtNyplU5Ef8Fzve4vZ0bWx\n7p1e6DPjSIgmyjIeCUZfaNJDuMh4Dd1SzHBE4ZdxRe3JGDDwMRR1H+/XcHYbjWmU\nSAEqqr/yXkIxKBESMmEex4j3gmhSSMypIHn+/3Itm2tSzByJeSP4PPEfIqKPz/ej\n8pRh0YS85BYt7YBoKtVPa95F4OsF27H85Elw47rNluvdzdR43yhvSXmuQ46cqrut\nUN19AmyAp0D8471myIzsMal6QrHzNvEKC/1uXQIDAQABAoIBAGV7poazSC1WDYpc\nZH+XxmBwSMnhoIZtBpaTqTREvmXAlMgvUB7zjUyisFLZzRLpEEzRxh4wbRNyCiwR\nz3u+RU5UAP8e9FB2W4mPOCNJwQKJcqbVsm6V2WJcHtPRJnPDcP/iqmc6hXG/QUKM\nLe0wQcr5s4qOfJ3PzX5fxMa1eRUjYrS/6/d+JWvdNOnLohoniP0DMfrUBJP9X6hH\nsPuuLPSYJuh5S3aVYg9CxR2koWsHqEHIMMVB+NN1lTWBLeXx5Rptu6hFraVb6Tpq\nIzcbDA3AU1u3EwCSWCqtFWYAgkSszWOhqnzfoJRALIA+/8D0FcD6qc+j2x64ZiM/\naqbJjjkCgYEA8rvScP+q2B4aJwRWacuPdeLXJlJtdicp/DGnaGyqwMgoDJHklB2t\nnnpESpfab0B/GmycC02pHuwE7gQ49ERO6KKZCraMWGTADr0+6SGvzbiWi1WHfw8C\nlFVQXyZfZs5ju0Kg6qFzfFJEt/ZYGmBvzgH+n5rrO10+fOpz/sOtNqsCgYEA2Cju\n39Hn3k/ZfjxVLWp5CLfEi/+bmMVmKb2oO5RWvZIlo2AVYSpZE3IUO3SSqcOdefPR\nmLImpkWFi8sIstwMQOgAhBbFXG239DaUSwVnEzv1R1Hkf6E5rOWRcIhqKWAQT0Qr\nX7h4RTqubbIAmW3UkrFQsfX7hZv54oobA/GsjxcCgYBlaa15gofpdWItzPUhjGeq\ntBR5sVSEWcaD1GcCDOymULnSzp12eJPSM3kWxS0A8CxqaNglLNQs1CUXIHJ/M47Y\nSR6xyCUIxUcsoUqIcoeV5roXCqvqnOXR/Xbv2gNf23j1gtfiT4QFfAWz6ltS4dm0\nc0bjfgErs0BpRjciSLS0swKBgFZIgJF3CEcFOJvbGWT3izifoiT/8uwYX59pxS2D\nGNyy6bM9N0uBy+ynLMxOy/xXyRRU7uU0t5jHR3d1pBNBIuMFuK8BJ+atJTCmWKtZ\njLtww4ekeME5afxJ5rQ0v6ukXN5HJ8kdqWR4+AdxdivIW4HypXNj7PJ4QFbdKct5\nPJghAoGBAL7SkHK8WWVLDLzgZ/28i2nPdZnlLzeVnAwYipIfX4zIsWEcoricIEsH\nLBraY6urr6uhI1deHOY/qkb/zsHYRKuD/4xGuZXh9kt1UKFcvZk5Cxy2N7U8W1HH\nfsSmFyqX3NAhE+GgJKU3XE+ljzQfIA5W1bMCXW9fjjAe+201tOh/\n-----END RSA PRIVATE KEY-----\n", saml_options["xmlsec_privatekey"]
    assert_equal "-----BEGIN CERTIFICATE-----\nMIIDpjCCAo4CCQCycttVqk/QbTANBgkqhkiG9w0BAQUFADCBlDELMAkGA1UEBhMC\nVVMxEDAOBgNVBAgTB0FyaXpvbmExEzARBgNVBAcTClNjb3R0c2RhbGUxFTATBgNV\nBAoTDENocm9udXMgQ29ycDEPMA0GA1UECxMGTWVudG9yMRYwFAYDVQQDFA0qLmNo\ncm9udXMuY29tMR4wHAYJKoZIhvcNAQkBFg9vcHNAY2hyb251cy5jb20wHhcNMTQw\nOTI1MDcwNDMzWhcNMjQwOTIyMDcwNDMzWjCBlDELMAkGA1UEBhMCVVMxEDAOBgNV\nBAgTB0FyaXpvbmExEzARBgNVBAcTClNjb3R0c2RhbGUxFTATBgNVBAoTDENocm9u\ndXMgQ29ycDEPMA0GA1UECxMGTWVudG9yMRYwFAYDVQQDFA0qLmNocm9udXMuY29t\nMR4wHAYJKoZIhvcNAQkBFg9vcHNAY2hyb251cy5jb20wggEiMA0GCSqGSIb3DQEB\nAQUAA4IBDwAwggEKAoIBAQDM9UlnD6ioPnDhQ4FthKFxg1S61P33DN3+uVP8gztc\nd65mz5xlEnJUabB9jCgM7GGucYftn26ekCljCgP9BBhFf0baRi03KmVTkR/wXO97\ni9nRtbHunV7oM+NIiCbKMh4JRl9o0kO4yHgN3VLMcEThl3FF7ckYMPAxFHUf79dw\ndhuNaZRIASqqv/JeQjEoERIyYR7HiPeCaFJIzKkgef7/ci2ba1LMHIl5I/g88R8i\noo/P96PylGHRhLzkFi3tgGgq1U9r3kXg6wXbsfzkSXDjus2W693N1HjfKG9Jea5D\njpyqu61Q3X0CbICnQPzjvWbIjOwxqXpCsfM28QoL/W5dAgMBAAEwDQYJKoZIhvcN\nAQEFBQADggEBABKOI4cp6Q9k+rOtr6uK79PfHbXY2EOPtblJa9cWq5basUW6r+F+\nI6pJy1dRXRx02W609vcFOqhH+F/Lzp8rhk5sYmBZ3nXPY9aRxOwgzZqjNn+WQS/e\nKf4zvT8AdLRI5mPNLSZrEQpUQlLuvlY2YfB6JKO/Iv00NiEabAEBfLGZyCNKdwVb\nPbcbGzfMU8jD0fX1drgolsqtSk/ZFEF1g/+b0e3NpFkxxVZq/LBG1i0sjeZ/SbqW\n4XTha46OieEBOfHEV73hHIAzMcOxwmqmcKqBtz7CgLeo6hgXSyy17sVShAVQzykf\n85+3UmRABRchQRanNT4n8TdjJZdav/Wi+qs=\n-----END CERTIFICATE-----\n", saml_options["xmlsec_certificate"]
    assert_equal "I5dm8FNwgAvQc4RFYFt3FA", saml_options["xmlsec_privatekey_pwd"]
    assert_equal org.url, saml_options["issuer"]
    assert_equal "bcdb6805fcc0498d69ed040d15f83f3bf10d05ca", saml_options["idp_cert_fingerprint"]
  end

  def test_get_saml_options_update_certificate_only_from_params
    org = programs(:org_primary)
    org.auth_configs.create!(auth_type: AuthConfig::Type::SAML)
    saml_auth = org.saml_auth
    saml_options = {}
    saml_options["idp_destination"] = saml_options["idp_sso_target_url"] = "https://abcd.com"
    saml_options["xmlsec_privatekey"] = "-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEAzPVJZw+oqD5w4UOBbYShcYNUutT99wzd/rlT/IM7XHeuZs+c\nZRJyVGmwfYwoDOxhrnGH7Z9unpApYwoD/QQYRX9G2kYtNyplU5Ef8Fzve4vZ0bWx\n7p1e6DPjSIgmyjIeCUZfaNJDuMh4Dd1SzHBE4ZdxRe3JGDDwMRR1H+/XcHYbjWmU\nSAEqqr/yXkIxKBESMmEex4j3gmhSSMypIHn+/3Itm2tSzByJeSP4PPEfIqKPz/ej\n8pRh0YS85BYt7YBoKtVPa95F4OsF27H85Elw47rNluvdzdR43yhvSXmuQ46cqrut\nUN19AmyAp0D8471myIzsMal6QrHzNvEKC/1uXQIDAQABAoIBAGV7poazSC1WDYpc\nZH+XxmBwSMnhoIZtBpaTqTREvmXAlMgvUB7zjUyisFLZzRLpEEzRxh4wbRNyCiwR\nz3u+RU5UAP8e9FB2W4mPOCNJwQKJcqbVsm6V2WJcHtPRJnPDcP/iqmc6hXG/QUKM\nLe0wQcr5s4qOfJ3PzX5fxMa1eRUjYrS/6/d+JWvdNOnLohoniP0DMfrUBJP9X6hH\nsPuuLPSYJuh5S3aVYg9CxR2koWsHqEHIMMVB+NN1lTWBLeXx5Rptu6hFraVb6Tpq\nIzcbDA3AU1u3EwCSWCqtFWYAgkSszWOhqnzfoJRALIA+/8D0FcD6qc+j2x64ZiM/\naqbJjjkCgYEA8rvScP+q2B4aJwRWacuPdeLXJlJtdicp/DGnaGyqwMgoDJHklB2t\nnnpESpfab0B/GmycC02pHuwE7gQ49ERO6KKZCraMWGTADr0+6SGvzbiWi1WHfw8C\nlFVQXyZfZs5ju0Kg6qFzfFJEt/ZYGmBvzgH+n5rrO10+fOpz/sOtNqsCgYEA2Cju\n39Hn3k/ZfjxVLWp5CLfEi/+bmMVmKb2oO5RWvZIlo2AVYSpZE3IUO3SSqcOdefPR\nmLImpkWFi8sIstwMQOgAhBbFXG239DaUSwVnEzv1R1Hkf6E5rOWRcIhqKWAQT0Qr\nX7h4RTqubbIAmW3UkrFQsfX7hZv54oobA/GsjxcCgYBlaa15gofpdWItzPUhjGeq\ntBR5sVSEWcaD1GcCDOymULnSzp12eJPSM3kWxS0A8CxqaNglLNQs1CUXIHJ/M47Y\nSR6xyCUIxUcsoUqIcoeV5roXCqvqnOXR/Xbv2gNf23j1gtfiT4QFfAWz6ltS4dm0\nc0bjfgErs0BpRjciSLS0swKBgFZIgJF3CEcFOJvbGWT3izifoiT/8uwYX59pxS2D\nGNyy6bM9N0uBy+ynLMxOy/xXyRRU7uU0t5jHR3d1pBNBIuMFuK8BJ+atJTCmWKtZ\njLtww4ekeME5afxJ5rQ0v6ukXN5HJ8kdqWR4+AdxdivIW4HypXNj7PJ4QFbdKct5\nPJghAoGBAL7SkHK8WWVLDLzgZ/28i2nPdZnlLzeVnAwYipIfX4zIsWEcoricIEsH\nLBraY6urr6uhI1deHOY/qkb/zsHYRKuD/4xGuZXh9kt1UKFcvZk5Cxy2N7U8W1HH\nfsSmFyqX3NAhE+GgJKU3XE+ljzQfIA5W1bMCXW9fjjAe+201tOh/\n-----END RSA PRIVATE KEY-----\n"
    saml_options["xmlsec_certificate"] = "-----BEGIN CERTIFICATE-----\nMIIDpjCCAo4CCQCycttVqk/QbTANBgkqhkiG9w0BAQUFADCBlDELMAkGA1UEBhMC\nVVMxEDAOBgNVBAgTB0FyaXpvbmExEzARBgNVBAcTClNjb3R0c2RhbGUxFTATBgNV\nBAoTDENocm9udXMgQ29ycDEPMA0GA1UECxMGTWVudG9yMRYwFAYDVQQDFA0qLmNo\ncm9udXMuY29tMR4wHAYJKoZIhvcNAQkBFg9vcHNAY2hyb251cy5jb20wHhcNMTQw\nOTI1MDcwNDMzWhcNMjQwOTIyMDcwNDMzWjCBlDELMAkGA1UEBhMCVVMxEDAOBgNV\nBAgTB0FyaXpvbmExEzARBgNVBAcTClNjb3R0c2RhbGUxFTATBgNVBAoTDENocm9u\ndXMgQ29ycDEPMA0GA1UECxMGTWVudG9yMRYwFAYDVQQDFA0qLmNocm9udXMuY29t\nMR4wHAYJKoZIhvcNAQkBFg9vcHNAY2hyb251cy5jb20wggEiMA0GCSqGSIb3DQEB\nAQUAA4IBDwAwggEKAoIBAQDM9UlnD6ioPnDhQ4FthKFxg1S61P33DN3+uVP8gztc\nd65mz5xlEnJUabB9jCgM7GGucYftn26ekCljCgP9BBhFf0baRi03KmVTkR/wXO97\ni9nRtbHunV7oM+NIiCbKMh4JRl9o0kO4yHgN3VLMcEThl3FF7ckYMPAxFHUf79dw\ndhuNaZRIASqqv/JeQjEoERIyYR7HiPeCaFJIzKkgef7/ci2ba1LMHIl5I/g88R8i\noo/P96PylGHRhLzkFi3tgGgq1U9r3kXg6wXbsfzkSXDjus2W693N1HjfKG9Jea5D\njpyqu61Q3X0CbICnQPzjvWbIjOwxqXpCsfM28QoL/W5dAgMBAAEwDQYJKoZIhvcN\nAQEFBQADggEBABKOI4cp6Q9k+rOtr6uK79PfHbXY2EOPtblJa9cWq5basUW6r+F+\nI6pJy1dRXRx02W609vcFOqhH+F/Lzp8rhk5sYmBZ3nXPY9aRxOwgzZqjNn+WQS/e\nKf4zvT8AdLRI5mPNLSZrEQpUQlLuvlY2YfB6JKO/Iv00NiEabAEBfLGZyCNKdwVb\nPbcbGzfMU8jD0fX1drgolsqtSk/ZFEF1g/+b0e3NpFkxxVZq/LBG1i0sjeZ/SbqW\n4XTha46OieEBOfHEV73hHIAzMcOxwmqmcKqBtz7CgLeo6hgXSyy17sVShAVQzykf\n85+3UmRABRchQRanNT4n8TdjJZdav/Wi+qs=\n-----END CERTIFICATE-----\n"
    saml_options["xmlsec_privatekey_pwd"] = "I5dm8FNwgAvQc4RFYFt3FA"
    saml_options["issuer"] = org.url
    saml_options["idp_cert_fingerprint"] = "81fe8bfe87576c3ecb22426f8e57847382917acf"
    saml_auth.set_options!(saml_options)
    stub_saml_sso_files(org.id)
    SamlAutomatorUtils.stubs(:get_sso_target_url).returns("https://abcd.com")
    saml_files = SamlAutomatorUtils::SamlFileUtils.get_saml_files_from_s3(org.id)
    SamlAutomatorUtils.expects(:get_cert_text_from_metadata).never
    saml_options = SamlAutomatorUtils.get_saml_options(org, saml_files, idp_certificate: File.read(File.join(Rails.root, "test", "fixtures", "files", "saml_sso", "20140925070427_cert.pem")), update_certificate_only: true)

    assert_equal "https://abcd.com", saml_options["idp_destination"]
    assert_equal "https://abcd.com", saml_options["idp_sso_target_url"]
    assert_equal "-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEAzPVJZw+oqD5w4UOBbYShcYNUutT99wzd/rlT/IM7XHeuZs+c\nZRJyVGmwfYwoDOxhrnGH7Z9unpApYwoD/QQYRX9G2kYtNyplU5Ef8Fzve4vZ0bWx\n7p1e6DPjSIgmyjIeCUZfaNJDuMh4Dd1SzHBE4ZdxRe3JGDDwMRR1H+/XcHYbjWmU\nSAEqqr/yXkIxKBESMmEex4j3gmhSSMypIHn+/3Itm2tSzByJeSP4PPEfIqKPz/ej\n8pRh0YS85BYt7YBoKtVPa95F4OsF27H85Elw47rNluvdzdR43yhvSXmuQ46cqrut\nUN19AmyAp0D8471myIzsMal6QrHzNvEKC/1uXQIDAQABAoIBAGV7poazSC1WDYpc\nZH+XxmBwSMnhoIZtBpaTqTREvmXAlMgvUB7zjUyisFLZzRLpEEzRxh4wbRNyCiwR\nz3u+RU5UAP8e9FB2W4mPOCNJwQKJcqbVsm6V2WJcHtPRJnPDcP/iqmc6hXG/QUKM\nLe0wQcr5s4qOfJ3PzX5fxMa1eRUjYrS/6/d+JWvdNOnLohoniP0DMfrUBJP9X6hH\nsPuuLPSYJuh5S3aVYg9CxR2koWsHqEHIMMVB+NN1lTWBLeXx5Rptu6hFraVb6Tpq\nIzcbDA3AU1u3EwCSWCqtFWYAgkSszWOhqnzfoJRALIA+/8D0FcD6qc+j2x64ZiM/\naqbJjjkCgYEA8rvScP+q2B4aJwRWacuPdeLXJlJtdicp/DGnaGyqwMgoDJHklB2t\nnnpESpfab0B/GmycC02pHuwE7gQ49ERO6KKZCraMWGTADr0+6SGvzbiWi1WHfw8C\nlFVQXyZfZs5ju0Kg6qFzfFJEt/ZYGmBvzgH+n5rrO10+fOpz/sOtNqsCgYEA2Cju\n39Hn3k/ZfjxVLWp5CLfEi/+bmMVmKb2oO5RWvZIlo2AVYSpZE3IUO3SSqcOdefPR\nmLImpkWFi8sIstwMQOgAhBbFXG239DaUSwVnEzv1R1Hkf6E5rOWRcIhqKWAQT0Qr\nX7h4RTqubbIAmW3UkrFQsfX7hZv54oobA/GsjxcCgYBlaa15gofpdWItzPUhjGeq\ntBR5sVSEWcaD1GcCDOymULnSzp12eJPSM3kWxS0A8CxqaNglLNQs1CUXIHJ/M47Y\nSR6xyCUIxUcsoUqIcoeV5roXCqvqnOXR/Xbv2gNf23j1gtfiT4QFfAWz6ltS4dm0\nc0bjfgErs0BpRjciSLS0swKBgFZIgJF3CEcFOJvbGWT3izifoiT/8uwYX59pxS2D\nGNyy6bM9N0uBy+ynLMxOy/xXyRRU7uU0t5jHR3d1pBNBIuMFuK8BJ+atJTCmWKtZ\njLtww4ekeME5afxJ5rQ0v6ukXN5HJ8kdqWR4+AdxdivIW4HypXNj7PJ4QFbdKct5\nPJghAoGBAL7SkHK8WWVLDLzgZ/28i2nPdZnlLzeVnAwYipIfX4zIsWEcoricIEsH\nLBraY6urr6uhI1deHOY/qkb/zsHYRKuD/4xGuZXh9kt1UKFcvZk5Cxy2N7U8W1HH\nfsSmFyqX3NAhE+GgJKU3XE+ljzQfIA5W1bMCXW9fjjAe+201tOh/\n-----END RSA PRIVATE KEY-----\n", saml_options["xmlsec_privatekey"]
    assert_equal "-----BEGIN CERTIFICATE-----\nMIIDpjCCAo4CCQCycttVqk/QbTANBgkqhkiG9w0BAQUFADCBlDELMAkGA1UEBhMC\nVVMxEDAOBgNVBAgTB0FyaXpvbmExEzARBgNVBAcTClNjb3R0c2RhbGUxFTATBgNV\nBAoTDENocm9udXMgQ29ycDEPMA0GA1UECxMGTWVudG9yMRYwFAYDVQQDFA0qLmNo\ncm9udXMuY29tMR4wHAYJKoZIhvcNAQkBFg9vcHNAY2hyb251cy5jb20wHhcNMTQw\nOTI1MDcwNDMzWhcNMjQwOTIyMDcwNDMzWjCBlDELMAkGA1UEBhMCVVMxEDAOBgNV\nBAgTB0FyaXpvbmExEzARBgNVBAcTClNjb3R0c2RhbGUxFTATBgNVBAoTDENocm9u\ndXMgQ29ycDEPMA0GA1UECxMGTWVudG9yMRYwFAYDVQQDFA0qLmNocm9udXMuY29t\nMR4wHAYJKoZIhvcNAQkBFg9vcHNAY2hyb251cy5jb20wggEiMA0GCSqGSIb3DQEB\nAQUAA4IBDwAwggEKAoIBAQDM9UlnD6ioPnDhQ4FthKFxg1S61P33DN3+uVP8gztc\nd65mz5xlEnJUabB9jCgM7GGucYftn26ekCljCgP9BBhFf0baRi03KmVTkR/wXO97\ni9nRtbHunV7oM+NIiCbKMh4JRl9o0kO4yHgN3VLMcEThl3FF7ckYMPAxFHUf79dw\ndhuNaZRIASqqv/JeQjEoERIyYR7HiPeCaFJIzKkgef7/ci2ba1LMHIl5I/g88R8i\noo/P96PylGHRhLzkFi3tgGgq1U9r3kXg6wXbsfzkSXDjus2W693N1HjfKG9Jea5D\njpyqu61Q3X0CbICnQPzjvWbIjOwxqXpCsfM28QoL/W5dAgMBAAEwDQYJKoZIhvcN\nAQEFBQADggEBABKOI4cp6Q9k+rOtr6uK79PfHbXY2EOPtblJa9cWq5basUW6r+F+\nI6pJy1dRXRx02W609vcFOqhH+F/Lzp8rhk5sYmBZ3nXPY9aRxOwgzZqjNn+WQS/e\nKf4zvT8AdLRI5mPNLSZrEQpUQlLuvlY2YfB6JKO/Iv00NiEabAEBfLGZyCNKdwVb\nPbcbGzfMU8jD0fX1drgolsqtSk/ZFEF1g/+b0e3NpFkxxVZq/LBG1i0sjeZ/SbqW\n4XTha46OieEBOfHEV73hHIAzMcOxwmqmcKqBtz7CgLeo6hgXSyy17sVShAVQzykf\n85+3UmRABRchQRanNT4n8TdjJZdav/Wi+qs=\n-----END CERTIFICATE-----\n", saml_options["xmlsec_certificate"]
    assert_equal "I5dm8FNwgAvQc4RFYFt3FA", saml_options["xmlsec_privatekey_pwd"]
    assert_equal org.url, saml_options["issuer"]
    assert_equal "bb1892e7f8a23ebcce0cfe5c3045ec3dabadcf3f", saml_options["idp_cert_fingerprint"]
  end

  private

  def mock_s3_objects(options = {})
    S3Helper.expects(:get_objects_with_prefix).returns(s3_objects(options)).at_least(0)
  end

  def s3_objects(options = {})
    timestamp = Time.now.utc.strftime('%Y%m%d%H%M%S')
    unless options[:except_sp_metadata]
      sp_metadata = mock()
      sp_metadata.stubs(:key).returns("#{timestamp}_SP_Metadata.xml")
    end
    unless options[:except_idp_metadata]
      idp_metadata = mock()
      idp_metadata.stubs(:key).returns("#{timestamp}_IDP_Metadata.xml")
    end
    unless options[:except_passphrase]
      passphrase = mock()
      passphrase.stubs(:key).returns("#{timestamp}_passphrase")
    end
    unless options[:except_cert]
      certificate = mock()
      certificate.stubs(:key).returns("#{timestamp}_cert.pem")
    end
    unless options[:except_key]
      key = mock()
      key.stubs(:key).returns("#{timestamp}_key.pem")
    end
    [sp_metadata, idp_metadata, passphrase, certificate, key].compact
  end

end