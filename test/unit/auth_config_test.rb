require_relative './../test_helper.rb'

class AuthConfigTest < ActiveSupport::TestCase

  def test_default_scope
    auth_config = programs(:org_primary).chronus_auth
    assert_difference("AuthConfig.count", -1) { auth_config.disable! }
    assert_difference("AuthConfig.count", 1) { auth_config.enable! }
  end

  def test_validations
    auth_config = AuthConfig.new
    assert_false auth_config.valid?
    assert_equal ["can't be blank"], auth_config.errors[:organization]
    assert_equal ["is not included in the list"], auth_config.errors[:auth_type]
  end

  def test_validate_auth_type_uniqueness
    organization = programs(:org_primary)

    AuthConfig::Type.all.each do |auth_type|
      organization.auth_configs.create!(auth_type: auth_type) if auth_type != AuthConfig::Type::CHRONUS
      e = assert_raise ActiveRecord::RecordInvalid do
        organization.auth_configs.create!(auth_type: auth_type)
      end
      assert_equal "Validation failed: Only one #{AuthConfig::Type.verbose(auth_type)} login is allowed per organization.", e.message
    end
  end

  def test_validate_auth_type_uniqueness_for_default_oauths
    organization = programs(:org_primary)

    e = assert_raise ActiveRecord::RecordInvalid do
      organization.auth_configs.create!(AuthConfig.attr_value_map_for_default_auths[1])
    end
    assert_equal "Validation failed: Only one LinkedIn login is allowed per organization.", e.message

    e = assert_raise ActiveRecord::RecordInvalid do
      organization.auth_configs.create!(AuthConfig.attr_value_map_for_default_auths[2])
    end
    assert_equal "Validation failed: Only one Google login is allowed per organization.", e.message
  end

  def test_validate_enabled
    auth_configs = programs(:org_primary).auth_configs
    auth_configs[1..-1].map(&:disable!)
    e = assert_raise ActiveRecord::RecordInvalid do
      auth_configs[0].disable!
    end
    assert_equal "Validation failed: An organization must have at least one login enabled.", e.message
  end

  def test_login_identifiers_assoc
    member = members(:f_admin)
    organization = member.organization
    auth_config = organization.auth_configs.create!(auth_type: AuthConfig::Type::SAML)
    member.login_identifiers.create!(auth_config: auth_config, identifier: "uid")
    assert_equal_unordered [organization.chronus_auth, auth_config], member.auth_configs

    assert_difference "member.login_identifiers.count", -1 do
      auth_config.destroy
    end
    assert_equal [organization.chronus_auth], member.reload.auth_configs
  end

  def test_title_globalized
    auth_config = programs(:org_primary).auth_configs.create!(auth_type: AuthConfig::Type::SAML, title: "en_title")
    Globalize.with_locale("fr-CA") do
      auth_config.update_attributes(title: "fr_title")
    end
    assert_equal 2, auth_config.reload.translations.count
    assert_equal "en_title", auth_config.translations[0].title
    assert_equal "fr_title", auth_config.translations[1].title
    assert_equal :"en", auth_config.translations[0].locale
    assert_equal :"fr-CA", auth_config.translations[1].locale
  end

  def test_password_message_globalized
    chronus_auth = programs(:org_primary).chronus_auth
    chronus_auth.update_attributes!(password_message: "en_password_message")

    Globalize.with_locale("fr-CA") do
      chronus_auth.update_attributes(password_message: "fr_password_message")
    end
    assert_equal 2, chronus_auth.reload.translations.count
    assert_equal "en_password_message", chronus_auth.translations[0].password_message
    assert_equal "fr_password_message", chronus_auth.translations[1].password_message
    assert_equal :"en", chronus_auth.translations[0].locale
    assert_equal :"fr-CA", chronus_auth.translations[1].locale
  end

  def test_type_verbose
    AuthConfig::Type.all.each do |auth_type|
      type_verbose =
        case auth_type
        when AuthConfig::Type::CHRONUS
          "Email"
        when AuthConfig::Type::OPENSSL
          "OpenSSL"
        when AuthConfig::Type::SAML
          "SAML 2.0"
        when AuthConfig::Type::BBNC
          "BBNC"
        when AuthConfig::Type::LDAP
          "LDAP"
        when AuthConfig::Type::Cookie
          "Cookie Based"
        when AuthConfig::Type::SOAP
          "SOAP"
        when AuthConfig::Type::OPEN
          "OAuth 2.0"
        end
      assert_equal type_verbose, AuthConfig::Type.verbose(auth_type)
    end
  end

  def test_title
    organization = programs(:org_primary)
    organization.auth_configs.create!(auth_type: AuthConfig::Type::SAML)
    auth_configs = AuthConfig.classify(organization.auth_configs)

    chronus_auth, linkedin_oauth, google_oauth = auth_configs[:default]
    chronus_auth.update_attributes!(title: "Chronus Login")
    linkedin_oauth.update_attributes!(title: "LinkedIn OAuth Login")
    google_oauth.update_attributes!(title: "Google OAuth Login")
    assert_equal "Email", chronus_auth.title
    assert_equal "LinkedIn", linkedin_oauth.title
    assert_equal "Google", google_oauth.title

    custom_auth = auth_configs[:custom][0]
    assert_equal "SAML Login", custom_auth.title
    custom_auth.title = "University Login"
    assert_equal "University Login", custom_auth.title
  end

  def test_logo_url
    organization = programs(:org_primary)
    organization.auth_configs.create!(auth_type: AuthConfig::Type::SAML)
    auth_configs = AuthConfig.classify(organization.auth_configs)

    chronus_auth, linkedin_oauth, google_oauth = auth_configs[:default]
    auth_configs[:default].each do |auth_config|
      auth_config.logo = fixture_file_upload(File.join("files", "test_pic.png"), "image/png")
      auth_config.save!
    end
    assert_equal ChronusAuth::LOGO, chronus_auth.logo_url
    assert_equal OpenAuthUtils::Configurations::Linkedin::LOGO, linkedin_oauth.logo_url
    assert_equal OpenAuthUtils::Configurations::Google::LOGO, google_oauth.logo_url

    custom_auth = auth_configs[:custom][0]
    assert_nil custom_auth.logo_url
    custom_auth.logo = fixture_file_upload(File.join("files", "test_pic.png"), "image/png")
    custom_auth.save!
    assert_not_nil custom_auth.logo_url
    assert_equal custom_auth.logo.url, custom_auth.logo_url
  end

  def test_indigenous_and_non_indigenous
    organization = programs(:org_primary)
    chronus_auth = organization.chronus_auth
    assert chronus_auth.indigenous?
    assert_false chronus_auth.non_indigenous?
    assert_equal_unordered [organization.linkedin_oauth, organization.google_oauth], organization.auth_configs.non_indigenous

    (AuthConfig::Type.all - [AuthConfig::Type::CHRONUS]).each do |auth_type|
      auth_config = AuthConfig.new(auth_type: auth_type)
      assert_false auth_config.indigenous?
      assert auth_config.non_indigenous?
    end
  end

  def test_remote_login
    auth_config = AuthConfig.new

    AuthConfig::AUTHS_WITH_REMOTE_LOGIN.each do |auth_type|
      auth_config.auth_type = auth_type
      assert auth_config.remote_login?
    end

    (AuthConfig::Type.all - AuthConfig::AUTHS_WITH_REMOTE_LOGIN).each do |auth_type|
      auth_config.auth_type = auth_type
      assert_false auth_config.remote_login?
    end

    auth_config.auth_type = AuthConfig::Type::SOAP
    assert_false auth_config.remote_login?
    auth_config.stubs(:token_based_soap_auth?).returns(true)
    assert auth_config.remote_login?
  end

  def test_remote_login_url
    auth_config = programs(:org_primary).auth_configs.create!(auth_type: AuthConfig::AUTHS_WITH_REMOTE_LOGIN.sample)
    auth_config.set_options!("url" => "google.com")
    assert_equal "google.com", auth_config.reload.remote_login_url
  end

  def test_get_and_set_options
    organization = programs(:org_primary)
    organization.auth_configs.destroy_all

    auth_config = organization.auth_configs.new
    auth_config.auth_type = AuthConfig::AUTHS_WITH_BASE64_ENCODING.sample
    auth_config.set_options!("config" => "value")
    assert_equal( { "config" => "value" }, auth_config.get_options)
    assert_equal( { "config" => "value" }, Marshal.load(Base64.decode64(auth_config.config)))

    auth_config.auth_type = (AuthConfig::Type.all - AuthConfig::AUTHS_WITH_BASE64_ENCODING).sample
    auth_config.set_options!( { "config" => "value" } )
    assert_equal( { "config" => "value" }, auth_config.get_options)
    assert_equal( { "config" => "value" }, Marshal.load(auth_config.config))
  end

  def test_get_options_for_default_oauths
    auth_configs = programs(:org_primary).auth_configs

    linkedin_oauth = auth_configs.find(&:linkedin_oauth?)
    OpenAuthUtils::Configurations::Linkedin.expects(:get_options).with(linkedin_oauth).at_least(1).returns("a" => 1)
    assert_equal_hash( { "a" => 1, "configuration" => OpenAuthUtils::Configurations::Linkedin }, linkedin_oauth.get_options)

    google_oauth = auth_configs.find(&:google_oauth?)
    OpenAuthUtils::Configurations::Google.expects(:get_options).with(google_oauth).at_least(1).returns("a" => 23)
    assert_equal_hash( { "a" => 23, "configuration" => OpenAuthUtils::Configurations::Google }, google_oauth.get_options)
  end

  def test_saml_auth
    AuthConfig::Type.all.each do |auth_type|
      if auth_type == AuthConfig::Type::SAML
        assert AuthConfig.new(auth_type: auth_type).saml_auth?
      else
        assert_false AuthConfig.new(auth_type: auth_type).saml_auth?
      end
    end
  end

  def test_oauth
    AuthConfig::Type.all.each do |auth_type|
      if auth_type == AuthConfig::Type::OPEN
        assert AuthConfig.new(auth_type: auth_type).oauth?
      else
        assert_false AuthConfig.new(auth_type: auth_type).oauth?
      end
    end
  end

  def test_token_based_soap_auth
    soap_auth = programs(:org_primary).auth_configs.create!(auth_type: AuthConfig::Type::SOAP)
    assert_false soap_auth.token_based_soap_auth?

    soap_auth.set_options!("set_token_url" => "www.google.com")
    assert_false soap_auth.token_based_soap_auth?

    soap_auth.set_options!("get_token_url" => "www.google.com")
    assert soap_auth.token_based_soap_auth?
  end

  def test_linkedin_and_google_oauth
    open_auth = AuthConfig.new(auth_type: AuthConfig::Type::OPEN, organization: programs(:org_primary))
    assert_false open_auth.linkedin_oauth?
    assert_false open_auth.google_oauth?

    open_auth.config = Base64.encode64(Marshal.dump("configuration" => OpenAuthUtils::Configurations::Linkedin))
    assert open_auth.linkedin_oauth?
    assert_false open_auth.google_oauth?

    open_auth.config = Base64.encode64(Marshal.dump("configuration" => OpenAuthUtils::Configurations::Google))
    assert_false open_auth.linkedin_oauth?
    assert open_auth.google_oauth?
  end

  def test_default_oauth
    auth_config = AuthConfig.new(auth_type: AuthConfig::Type::OPEN)
    auth_config.stubs(:default?).returns(false)
    assert_false auth_config.default_oauth?

    auth_config.stubs(:default?).returns(true)
    assert auth_config.default_oauth?

    (AuthConfig::Type.all - [AuthConfig::Type::OPEN]).each do |auth_type|
      auth_config.auth_type = auth_type
      assert_false auth_config.default_oauth?
    end
  end

  def test_saml_settings
    saml_auth = programs(:org_primary).auth_configs.create!(auth_type: AuthConfig::Type::SAML)
    saml_auth.set_options!(
      "idp_sso_target_url" => "https://fedauth-test.colorado.edu/idp/profile/SAML2/Redirect/SSO",
      "idp_base64_cert" => "base64 certificate content",
      "idp_cert_fingerprint" => "2C:4E:4D:74:5B:4E:8C:A2:A7:BD:26:E2:7E:D4:9A:32:69:0F:61:74",
      "xmlsec_certificate" => "CERT",
      "xmlsec_privatekey" => "KEY",
      "friendly_name" => "eduPersonPrincipalName",
      "idp_slo_target_url" => "https://fedauth-test.colorado.edu/idp/profile/SAML2/Logoff"
    )

    settings = saml_auth.saml_settings
    assert_equal Onelogin::Saml::Settings, settings.class
    assert_equal "https://fedauth-test.colorado.edu/idp/profile/SAML2/Redirect/SSO", settings.idp_sso_target_url
    assert_equal "https://fedauth-test.colorado.edu/idp/profile/SAML2/Logoff", settings.idp_slo_target_url
    assert_equal "base64 certificate content", settings.idp_base64_cert
    assert_equal "2C:4E:4D:74:5B:4E:8C:A2:A7:BD:26:E2:7E:D4:9A:32:69:0F:61:74", settings.idp_cert_fingerprint
    assert_equal "xmlsec1", settings.xmlsec1_path
    assert_equal "urn:oasis:names:tc:SAML:2.0:ac:classes:PasswordProtectedTransport", settings.requested_authn_context
    assert_equal "CERT", settings.xmlsec_certificate
    assert_equal "KEY", settings.xmlsec_privatekey
  end

  def test_generate_saml_slo_request
    saml_auth = create_saml_auth_with_slo
    assert saml_auth.generate_saml_slo_request({}).present?

    saml_auth.set_options!(saml_auth.get_options.except("idp_slo_target_url"))
    assert_nil saml_auth.generate_saml_slo_request({})
  end

  def test_default_and_custom
    auth_config = AuthConfig.new
    auth_config.stubs(:indigenous?).returns(true)
    assert auth_config.default?
    assert_false auth_config.custom?

    auth_config.stubs(:indigenous?).returns(false)
    auth_config.stubs(:linkedin_oauth?).returns(true)
    assert auth_config.default?
    assert_false auth_config.custom?

    auth_config.stubs(:linkedin_oauth?).returns(false)
    auth_config.stubs(:google_oauth?).returns(true)
    assert auth_config.default?
    assert_false auth_config.custom?

    auth_config.stubs(:google_oauth?).returns(false)
    assert_false auth_config.default?
    assert auth_config.custom?
  end

  def test_enable_disable
    auth_config = programs(:org_primary).chronus_auth
    assert auth_config.enabled?
    assert_false auth_config.disabled?

    auth_config.disable!
    assert_false auth_config.enabled?
    assert auth_config.disabled?

    auth_config.enable!
    assert auth_config.enabled?
    assert_false auth_config.disabled?
  end

  def test_remove_logo
    auth_config = programs(:org_primary).auth_configs.new(auth_type: AuthConfig::Type::SAML)
    auth_config.logo = fixture_file_upload(File.join("files", "test_pic.png"), "image/png")
    auth_config.save!
    assert auth_config.logo.exists?

    auth_config.remove_logo!
    assert_false auth_config.logo.exists?
  end

  def test_can_be_disabled
    auth_config = programs(:org_primary).auth_configs.new

    auth_config.stubs(:default?).returns(true)
    auth_config.organization.stubs(:standalone_auth?).returns(false)
    assert auth_config.can_be_disabled?

    auth_config.stubs(:default?).returns(false)
    assert_false auth_config.can_be_disabled?

    auth_config.organization.stubs(:standalone_auth?).returns(true)
    assert_false auth_config.can_be_disabled?

    auth_config.stubs(:default?).returns(true)
    assert_false auth_config.can_be_disabled?
  end

  def test_can_be_deleted
    auth_config = programs(:org_primary).auth_configs.new

    auth_config.stubs(:custom?).returns(true)
    auth_config.organization.stubs(:standalone_auth?).returns(false)
    assert auth_config.can_be_deleted?

    auth_config.stubs(:custom?).returns(false)
    assert_false auth_config.can_be_deleted?

    auth_config.organization.stubs(:standalone_auth?).returns(true)
    assert_false auth_config.can_be_deleted?

    auth_config.stubs(:custom?).returns(true)
    assert_false auth_config.can_be_deleted?
  end

  def test_use_browsertab_in_mobile
    auth_config = programs(:org_primary).auth_configs.new
    assert_false auth_config.use_browsertab_in_mobile?

    auth_config.expects(:google_oauth?).once.returns(true)
    assert auth_config.use_browsertab_in_mobile?
  end

  def test_get_attributes_for_mobile_single_logout
    saml_auth = create_saml_auth_with_slo
    attributes = { name_id: "Test", name_qualifier: "http://idp.ssocircle.com", session_index: "tewsat" }

    assert_nil AuthConfig.get_attributes_for_mobile_single_logout(nil, attributes)
    assert_nil AuthConfig.get_attributes_for_mobile_single_logout(programs(:org_primary).chronus_auth, attributes)
    attributes_map = AuthConfig.get_attributes_for_mobile_single_logout(saml_auth, attributes)
    assert_equal_unordered [:name_id, :session_index, :name_qualifier, :variables_to_be_set], attributes_map.keys
    assert_equal_unordered ["Test", "http://idp.ssocircle.com", "tewsat", "name_id,session_index,name_qualifier"], attributes_map.values
  end

  def test_classify
    organization = programs(:org_primary)
    custom_auth_1 = organization.auth_configs.create!(auth_type: AuthConfig::Type::SAML)
    custom_auth_2 = organization.auth_configs.create!(auth_type: AuthConfig::Type::OPEN)

    auth_configs = AuthConfig.classify(organization.auth_configs)
    assert_equal AuthConfig.attr_value_map_for_default_auths.size, auth_configs[:default].size
    assert auth_configs[:default][0].indigenous?
    assert auth_configs[:default][1].linkedin_oauth?
    assert auth_configs[:default][2].google_oauth?
    assert_equal_unordered [custom_auth_1, custom_auth_2], auth_configs[:custom]
  end

  def test_default_oath_methods
    assert_equal [:linkedin_oauth?, :google_oauth?], AuthConfig.default_oauth_methods
  end

  def test_attr_value_map_for_default_auths
    attr_value_map = AuthConfig.attr_value_map_for_default_auths
    assert_equal 3, attr_value_map.size
    assert_equal_hash( { auth_type: AuthConfig::Type::CHRONUS }, attr_value_map[0])
    assert_equal_hash( { auth_type: AuthConfig::Type::OPEN, enabled: false, config: Base64.encode64(Marshal.dump( { "configuration" => OpenAuthUtils::Configurations::Linkedin } )) }, attr_value_map[1])
    assert_equal_hash( { auth_type: AuthConfig::Type::OPEN, enabled: false, config: Base64.encode64(Marshal.dump( { "configuration" => OpenAuthUtils::Configurations::Google } )) }, attr_value_map[2])
  end

  private

  def create_saml_auth_with_slo
    saml_auth = programs(:org_primary).auth_configs.create!(auth_type: AuthConfig::Type::SAML)
    saml_auth.set_options!(
      "idp_sso_target_url" => "https://idp.ssocircle.com:443/sso/SSORedirect/metaAlias/ssocircle",
      "idp_cert_fingerprint" => "9f0898770d9f0948c45bf5d6db55cb037c3b280c",
      "idp_destination" => "https://idp.ssocircle.com:443/sso/SSORedirect/metaAlias/ssocircle",
      "xmlsec_privatekey" => "-----BEGIN PRIVATE KEY-----\nMIIEvwIBADANBgkqhkiG9w0BAQEFAASCBKkwggSlAgEAAoIBAQCaKH4lucss8UPp\nIplLbXxloTbgJMsqHgCry4DWLW3+OEUW0mUWKFJ88ZpY+kk0gvAVXY2kDo/KlhbJ\n8jbygAqW3TKpQ+AtKiDu930Bx9D6sgWPPdl1XCGhWExuG2exnjruMmd2ixf/4EFz\nGdj5GGwlw5TZYPtYlJT0ou1qkr7X+Wxl0sddrTr+vmUezKYCSrq8ARoe8toBJddN\nm2P2HvczuE2e2I83d00wHButLG2miNhHHuiizR07p5eLMLbSt5l6LmM+KDFPD/3x\n77I0MSLAoPEiCyEB1q6dcqamRSJuiya931HflitOSyC8AEP9bZ67tf8EmirLwKa0\nVfhqBtw/AgMBAAECggEAaiwzXaZN0eFFJX9n1vRMNe7Hza5potNRIQEi9eAKHooA\nw4wahR02WslHxbpzys/XrM9nKzPAQwYGIgZJY9Fd+bPVHZEbB+A5GHypwx0syEzt\n2U7+w361xtr6oOcNDt7stXtPmOyJlfiM+0o1DrKMYaIHlYPe+I403RyNqdXxzOrx\n1AZ4FOUYyTFlNeEQj9nrQpRzZb0XdGYp59T8tAYO/Lrx1TqIHAJ2oCBU3qbJCte9\nvl6Gu/keNPf6dafXoZnYutH0Q/Ktr3XP/4VJk8wu8Pk3hurUkUk+TGGtwgG/4And\nPA6Rc7ekvcnzqh5S3TA3LmFNl39kCukXzuvFlCTsuQKBgQDKlp5TvnqdeZxTqPYF\ni/eo4njB3w2+Agj0fqPSw7n8ZCdCTgq4A+UAzpiQ9+ckBV3BoByJqsTP7RziYwp6\nLk6p1QmpNB5arG51qsDobkMvO23UugMylVVXpL8vJi+UTjt4UGC3zmDzNIiInVux\n9S3RCQ6vV8OrczCxErWegrOWTQKBgQDCzSffEwiuX90jgX9n9kST/l2hwib+2OfA\noxBK23prHDDJtJDaDRvk2++gPksXZ167H4Sy1oZ7sz8AGo2Cg5uzb+IP3lDziAoj\nGxQgFVszE1ujNW6yyTzBUnuicpgd2KhPbD4CsKRubqv2PWfiWc/35xczfnYMZzSo\nyVX1mIVauwKBgQCwDOPZ8pWrc5seOJ5Tg6bc5LH8CFJw5GPT1JmY9u4RHxfezuMR\ntpCzetWqZURAUUmAkhs6p2QRLQUE1vyr4MILZE7Y86nNMjtrlc++LNPFn+d6DYvp\n0UwwtcJOvuhqAPI9Q9xI3tfxgZ2E2vpsU5xVI4HXbnVj8N5HgvLBpONboQKBgQCc\nOERqW+xRUuWYDMjsyY0zlgDmsTnulGo+jUaKkbp53VCu4ZRsmait/0cLHgnAShCp\nRdx4Qxv0Zcn3PlQPv5WE8Au9qA8JTia7AoNAO4A41KRfnYEZ9dI4QvqNSxL8lHxd\nvTN5mskzGqPjRFlkJ5xldTig/iCTT8zmMxgxbdA78wKBgQCj21qLCQhPzi544FVk\nDMKJzyP/MOKGSQUGMbHerLxnosVfr0qWMCktH8JH/ZyQ5TvLJuDWlmmns3FYTShn\nDsyZS9H1VezTSPrMTWzYaqVrAqwOlnjCjzqT9+tvTk27czFYxFwmunZCayBQ3UjH\nULaPZsOofhRoq17nLWGwP20AbQ==\n-----END PRIVATE KEY-----\n",
      "xmlsec_certificate" => "-----BEGIN CERTIFICATE-----\nMIIDpjCCAo4CCQCK0hY5T/4PLzANBgkqhkiG9w0BAQUFADCBlDELMAkGA1UEBhMC\nVVMxEDAOBgNVBAgTB0FyaXpvbmExEzARBgNVBAcTClNjb3R0c2RhbGUxFTATBgNV\nBAoTDENocm9udXMgQ29ycDEPMA0GA1UECxMGTWVudG9yMRYwFAYDVQQDFA0qLmNo\ncm9udXMuY29tMR4wHAYJKoZIhvcNAQkBFg9vcHNAY2hyb251cy5jb20wHhcNMTUx\nMDE5MDkwMjA4WhcNMjUxMDE2MDkwMjA4WjCBlDELMAkGA1UEBhMCVVMxEDAOBgNV\nBAgTB0FyaXpvbmExEzARBgNVBAcTClNjb3R0c2RhbGUxFTATBgNVBAoTDENocm9u\ndXMgQ29ycDEPMA0GA1UECxMGTWVudG9yMRYwFAYDVQQDFA0qLmNocm9udXMuY29t\nMR4wHAYJKoZIhvcNAQkBFg9vcHNAY2hyb251cy5jb20wggEiMA0GCSqGSIb3DQEB\nAQUAA4IBDwAwggEKAoIBAQCaKH4lucss8UPpIplLbXxloTbgJMsqHgCry4DWLW3+\nOEUW0mUWKFJ88ZpY+kk0gvAVXY2kDo/KlhbJ8jbygAqW3TKpQ+AtKiDu930Bx9D6\nsgWPPdl1XCGhWExuG2exnjruMmd2ixf/4EFzGdj5GGwlw5TZYPtYlJT0ou1qkr7X\n+Wxl0sddrTr+vmUezKYCSrq8ARoe8toBJddNm2P2HvczuE2e2I83d00wHButLG2m\niNhHHuiizR07p5eLMLbSt5l6LmM+KDFPD/3x77I0MSLAoPEiCyEB1q6dcqamRSJu\niya931HflitOSyC8AEP9bZ67tf8EmirLwKa0VfhqBtw/AgMBAAEwDQYJKoZIhvcN\nAQEFBQADggEBAHTVfLDRzT7Ey15treXJ6jfT9dpaglCwgAhfeIXg0bZ10KXP3JC6\nK5KAMxGiYPIDiC1adCnAxdPwj25ThYNmWb3K7V5yIn9XlVMT3kGmkQHyI0+5MnfK\nTvnFznsUeC05fyw50OHH1jKwFzRjjA6yp5BhAn5P6AfPPs9fmtSfstO3EXzYqG2R\ngTydizP2+tIpISqASVo6D788fK8yW5LbKsfUkq3kLzSb9cfPrfYDPgen3YB2sQ4n\nX4c0smFTzPKR/Pe5WbQvxJWf0kpzg/uWK4kzMfgPwzE2FtVC4yqlr80f9xHXh/QH\n9nut8QqnVda7QBhAQlOcghgFhxbO0UjE6hc=\n-----END CERTIFICATE-----\n",
      "xmlsec_privatekey_pwd"=>"cTfje8CQdD0L3HPToHhm7A",
      "issuer" => "withincrease.localhost.com",
      "idp_slo_target_url" => "https://idp.ssocircle.com:443/sso/IDPSloRedirect/metaAlias/ssocircle"
    )
    saml_auth
  end
end