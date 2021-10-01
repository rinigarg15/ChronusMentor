require_relative "./../../../test_helper"

# TODO: Move SAML related tests from SessionsControllerTest
class SAMLAuthTest < ActiveSupport::TestCase

  def test_validate_option
    options = friendly_name_saml_options
    options["validate"] = {
      "name_identifier" => "FriendlyName",
      "criterias" => [ {
        "criteria" => [
          { "attribute" => "eduPersonPrincipalName", "operator" => "eq", "value" => "test100@colorado.edu" }
        ]
      } ]
    }
    auth_config = create_saml_auth(options)

    # In Response, eduPersonPrincipalName: 'test100@colorado.edu'
    auth_obj = ProgramSpecificAuth.authenticate(auth_config, File.read("test/fixtures/files/saml_response"))
    assert_equal ProgramSpecificAuth::Status::NO_USER_EXISTENCE, auth_obj.status
    assert auth_obj.has_data_validation
    assert auth_obj.is_data_valid
    assert_nil auth_obj.member
    assert_nil auth_obj.permission_denied_message
  end

  def test_validate_option_fail
    options = name_saml_options
    options["validate"] = {
      "name_identifier" => "Name",
      "criterias" => [ {
        "criteria" => [
          { "attribute" => "username", "operator" => "regex", "value" => ".*@rmail.com" }
        ]
      } ],
      "fail_message" => "Not a valid member. Please use ymail.com"
    }
    auth_config = create_saml_auth(options)

    # In Response, username: 'aniketgajare@gmail.com'
    auth_obj = ProgramSpecificAuth.authenticate(auth_config, File.read("test/fixtures/files/saml_response_1"))
    assert_equal ProgramSpecificAuth::Status::PERMISSION_DENIED, auth_obj.status
    assert auth_obj.has_data_validation
    assert_false auth_obj.is_data_valid
    assert_nil auth_obj.member
    assert_equal "Not a valid member. Please use ymail.com", auth_obj.permission_denied_message
  end

  def test_validate_option_multiple_criteria
    member = members(:f_admin)
    options = name_saml_options
    options["validate"] = {
      "name_identifier" => "Name",
      "criterias" => [ {
        "criteria" => [
          { "attribute" => "username", "operator" => "regex", "value" => ".*@gmail.com" },
          { "attribute" => "userId", "operator" => "eq", "value" => "005i0000000xuCt" }
        ]
      } ],
      "fail_message" => "Not a valid member. Please use ymail.com"
    }
    auth_config = create_saml_auth(options)
    member.login_identifiers.create!(auth_config: auth_config, identifier: "aniketgajare@gmail.com")

    # In Response, username: 'aniketgajare@gmail.com' userId: '005i0000000xuCt'
    auth_obj = ProgramSpecificAuth.authenticate(auth_config, File.read("test/fixtures/files/saml_response_1"))
    assert_equal ProgramSpecificAuth::Status::AUTHENTICATION_SUCCESS, auth_obj.status
    assert auth_obj.has_data_validation
    assert auth_obj.is_data_valid
    assert_equal member, auth_obj.member
    assert_equal "Not a valid member. Please use ymail.com", auth_obj.permission_denied_message
  end

  def test_validate_option_for_multiple_criteria_fail
    options = name_saml_options
    options["validate"] = {
      "name_identifier" => "Name",
      "criterias" => [ {
        "criteria" => [
          { "attribute" => "username", "operator" => "regex", "value" => ".*@rmail.com" },
          { "attribute" => "userId", "operator" => "eq", "value" => "005i0000000xuCt" }
        ]
      } ],
      "fail_message" => "Not a valid member. Please use ymail.com"
    }
    auth_config = create_saml_auth(options)

    # In Response, username: 'aniketgajare@gmail.com'
    auth_obj = ProgramSpecificAuth.authenticate(auth_config, File.read("test/fixtures/files/saml_response_1"))
    assert_equal ProgramSpecificAuth::Status::PERMISSION_DENIED, auth_obj.status
    assert auth_obj.has_data_validation
    assert_false auth_obj.is_data_valid
    assert_nil auth_obj.member
    assert_equal "Not a valid member. Please use ymail.com", auth_obj.permission_denied_message
  end

  def test_validation_fail_ignored_for_registered_member
    member = members(:f_admin)
    options = name_saml_options
    options["validate"] = {
      "name_identifier" => "Name",
      "criterias" => [ {
        "criteria" => [
          { "attribute" => "username", "operator" => "regex", "value" => ".*@rmail.com" },
          { "attribute" => "username", "operator" => "", "value" => "" }
        ]
      } ],
      "fail_message" => "Not a valid member. Please use ymail.com"
    }
    auth_config = create_saml_auth(options)
    member.login_identifiers.create!(auth_config: auth_config, identifier: "aniketgajare@gmail.com")

    # In Response, username: "aniketgajare@gmail.com"
    auth_obj = ProgramSpecificAuth.authenticate(auth_config, File.read("test/fixtures/files/saml_response_1"))
    assert_equal ProgramSpecificAuth::Status::AUTHENTICATION_SUCCESS, auth_obj.status
    assert auth_obj.has_data_validation
    assert_false auth_obj.is_data_valid
    assert_equal member, auth_obj.member
    assert_equal "Not a valid member. Please use ymail.com", auth_obj.permission_denied_message
  end

  def test_saml_slo_and_test_set_variables_for_slo
    auth_config = create_saml_auth(saml_options_with_slo)

    auth_obj = ProgramSpecificAuth.authenticate(auth_config, File.read("test/fixtures/files/saml_response_3"))
    assert_equal "http://idp.ssocircle.com", auth_obj.name_qualifier
    assert_equal "s2092a7c9ee2ae3b37694e7c1f211d69dfc84af201", auth_obj.session_index
    assert_equal "TZmcE91NohanrJdihOMFqOTDeh6P", auth_obj.name_id
    assert auth_obj.slo_enabled
  end

  def test_get_attributes_for_saml_slo
    auth_config = create_saml_auth(saml_options_with_slo)

    attributes = { name_id: "Test", name_qualifier: "http://idp.ssocircle.com", session_index: "tewsat" }
    assert_equal_unordered SAMLAuth.get_attributes_for_saml_slo(attributes).keys, [:name_id, :session_index, :name_qualifier]
    assert_equal_unordered SAMLAuth.get_attributes_for_saml_slo(attributes).values, ["Test", "http://idp.ssocircle.com", "tewsat"]
  end

  def test_authenticate_with_no_x509_cert_in_samlresponse
    auth_config = create_saml_auth(saml_options_with_idp_base64_cert)

    auth_obj = ProgramSpecificAuth.authenticate(auth_config, File.read("test/fixtures/files/saml_response_4"))
    assert_equal ProgramSpecificAuth::Status::NO_USER_EXISTENCE, auth_obj.status
    assert_equal "michelle.biber@thermofisher.com", auth_obj.uid
  end

  private

  def create_saml_auth(options)
    auth_config = programs(:org_primary).auth_configs.new(auth_type: AuthConfig::Type::SAML)
    auth_config.set_options! options
    auth_config
  end

  def saml_options_with_slo
    {
      "idp_sso_target_url"=>"https://idp.ssocircle.com:443/sso/SSORedirect/metaAlias/ssocircle",
      "idp_cert_fingerprint"=>"9f0898770d9f0948c45bf5d6db55cb037c3b280c",
      "idp_destination"=>"https://idp.ssocircle.com:443/sso/SSORedirect/metaAlias/ssocircle",
      "xmlsec_privatekey"=>"-----BEGIN PRIVATE KEY-----\nMIIEvwIBADANBgkqhkiG9w0BAQEFAASCBKkwggSlAgEAAoIBAQCaKH4lucss8UPp\nIplLbXxloTbgJMsqHgCry4DWLW3+OEUW0mUWKFJ88ZpY+kk0gvAVXY2kDo/KlhbJ\n8jbygAqW3TKpQ+AtKiDu930Bx9D6sgWPPdl1XCGhWExuG2exnjruMmd2ixf/4EFz\nGdj5GGwlw5TZYPtYlJT0ou1qkr7X+Wxl0sddrTr+vmUezKYCSrq8ARoe8toBJddN\nm2P2HvczuE2e2I83d00wHButLG2miNhHHuiizR07p5eLMLbSt5l6LmM+KDFPD/3x\n77I0MSLAoPEiCyEB1q6dcqamRSJuiya931HflitOSyC8AEP9bZ67tf8EmirLwKa0\nVfhqBtw/AgMBAAECggEAaiwzXaZN0eFFJX9n1vRMNe7Hza5potNRIQEi9eAKHooA\nw4wahR02WslHxbpzys/XrM9nKzPAQwYGIgZJY9Fd+bPVHZEbB+A5GHypwx0syEzt\n2U7+w361xtr6oOcNDt7stXtPmOyJlfiM+0o1DrKMYaIHlYPe+I403RyNqdXxzOrx\n1AZ4FOUYyTFlNeEQj9nrQpRzZb0XdGYp59T8tAYO/Lrx1TqIHAJ2oCBU3qbJCte9\nvl6Gu/keNPf6dafXoZnYutH0Q/Ktr3XP/4VJk8wu8Pk3hurUkUk+TGGtwgG/4And\nPA6Rc7ekvcnzqh5S3TA3LmFNl39kCukXzuvFlCTsuQKBgQDKlp5TvnqdeZxTqPYF\ni/eo4njB3w2+Agj0fqPSw7n8ZCdCTgq4A+UAzpiQ9+ckBV3BoByJqsTP7RziYwp6\nLk6p1QmpNB5arG51qsDobkMvO23UugMylVVXpL8vJi+UTjt4UGC3zmDzNIiInVux\n9S3RCQ6vV8OrczCxErWegrOWTQKBgQDCzSffEwiuX90jgX9n9kST/l2hwib+2OfA\noxBK23prHDDJtJDaDRvk2++gPksXZ167H4Sy1oZ7sz8AGo2Cg5uzb+IP3lDziAoj\nGxQgFVszE1ujNW6yyTzBUnuicpgd2KhPbD4CsKRubqv2PWfiWc/35xczfnYMZzSo\nyVX1mIVauwKBgQCwDOPZ8pWrc5seOJ5Tg6bc5LH8CFJw5GPT1JmY9u4RHxfezuMR\ntpCzetWqZURAUUmAkhs6p2QRLQUE1vyr4MILZE7Y86nNMjtrlc++LNPFn+d6DYvp\n0UwwtcJOvuhqAPI9Q9xI3tfxgZ2E2vpsU5xVI4HXbnVj8N5HgvLBpONboQKBgQCc\nOERqW+xRUuWYDMjsyY0zlgDmsTnulGo+jUaKkbp53VCu4ZRsmait/0cLHgnAShCp\nRdx4Qxv0Zcn3PlQPv5WE8Au9qA8JTia7AoNAO4A41KRfnYEZ9dI4QvqNSxL8lHxd\nvTN5mskzGqPjRFlkJ5xldTig/iCTT8zmMxgxbdA78wKBgQCj21qLCQhPzi544FVk\nDMKJzyP/MOKGSQUGMbHerLxnosVfr0qWMCktH8JH/ZyQ5TvLJuDWlmmns3FYTShn\nDsyZS9H1VezTSPrMTWzYaqVrAqwOlnjCjzqT9+tvTk27czFYxFwmunZCayBQ3UjH\nULaPZsOofhRoq17nLWGwP20AbQ==\n-----END PRIVATE KEY-----\n",
      "xmlsec_certificate"=>"-----BEGIN CERTIFICATE-----\nMIIDpjCCAo4CCQCK0hY5T/4PLzANBgkqhkiG9w0BAQUFADCBlDELMAkGA1UEBhMC\nVVMxEDAOBgNVBAgTB0FyaXpvbmExEzARBgNVBAcTClNjb3R0c2RhbGUxFTATBgNV\nBAoTDENocm9udXMgQ29ycDEPMA0GA1UECxMGTWVudG9yMRYwFAYDVQQDFA0qLmNo\ncm9udXMuY29tMR4wHAYJKoZIhvcNAQkBFg9vcHNAY2hyb251cy5jb20wHhcNMTUx\nMDE5MDkwMjA4WhcNMjUxMDE2MDkwMjA4WjCBlDELMAkGA1UEBhMCVVMxEDAOBgNV\nBAgTB0FyaXpvbmExEzARBgNVBAcTClNjb3R0c2RhbGUxFTATBgNVBAoTDENocm9u\ndXMgQ29ycDEPMA0GA1UECxMGTWVudG9yMRYwFAYDVQQDFA0qLmNocm9udXMuY29t\nMR4wHAYJKoZIhvcNAQkBFg9vcHNAY2hyb251cy5jb20wggEiMA0GCSqGSIb3DQEB\nAQUAA4IBDwAwggEKAoIBAQCaKH4lucss8UPpIplLbXxloTbgJMsqHgCry4DWLW3+\nOEUW0mUWKFJ88ZpY+kk0gvAVXY2kDo/KlhbJ8jbygAqW3TKpQ+AtKiDu930Bx9D6\nsgWPPdl1XCGhWExuG2exnjruMmd2ixf/4EFzGdj5GGwlw5TZYPtYlJT0ou1qkr7X\n+Wxl0sddrTr+vmUezKYCSrq8ARoe8toBJddNm2P2HvczuE2e2I83d00wHButLG2m\niNhHHuiizR07p5eLMLbSt5l6LmM+KDFPD/3x77I0MSLAoPEiCyEB1q6dcqamRSJu\niya931HflitOSyC8AEP9bZ67tf8EmirLwKa0VfhqBtw/AgMBAAEwDQYJKoZIhvcN\nAQEFBQADggEBAHTVfLDRzT7Ey15treXJ6jfT9dpaglCwgAhfeIXg0bZ10KXP3JC6\nK5KAMxGiYPIDiC1adCnAxdPwj25ThYNmWb3K7V5yIn9XlVMT3kGmkQHyI0+5MnfK\nTvnFznsUeC05fyw50OHH1jKwFzRjjA6yp5BhAn5P6AfPPs9fmtSfstO3EXzYqG2R\ngTydizP2+tIpISqASVo6D788fK8yW5LbKsfUkq3kLzSb9cfPrfYDPgen3YB2sQ4n\nX4c0smFTzPKR/Pe5WbQvxJWf0kpzg/uWK4kzMfgPwzE2FtVC4yqlr80f9xHXh/QH\n9nut8QqnVda7QBhAQlOcghgFhxbO0UjE6hc=\n-----END CERTIFICATE-----\n",
      "xmlsec_privatekey_pwd"=>"cTfje8CQdD0L3HPToHhm7A",
      "issuer"=>"withincrease.localhost.com",
      "idp_slo_target_url"=>"https://idp.ssocircle.com:443/sso/IDPSloRedirect/metaAlias/ssocircle"
    }
  end

  def friendly_name_saml_options
    {
      "idp_sso_target_url" => "https://fedauth-test.colorado.edu/idp/profile/SAML2/Redirect/SSO",
      "idp_cert_fingerprint" => "96:8A:6B:8B:73:57:11:F3:A6:18:52:D6:C6:E2:6C:34:1F:9D:36:68",
      "xmlsec_certificate" => "-----BEGIN CERTIFICATE-----\nMIIDWzCCAkOgAwIBAgIJANezMu+9Ie8PMA0GCSqGSIb3DQEBBQUAMCcxJTAjBgNV\nBAMTHGxlZWRzc2FuZGJveC5yZWFsaXplZ29hbC5jb20wHhcNMTIwNTI4MTEzMjE5\nWhcNMjIwNTI2MTEzMjE5WjAnMSUwIwYDVQQDExxsZWVkc3NhbmRib3gucmVhbGl6\nZWdvYWwuY29tMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAl+DKdD2k\n9QlSmMT7J4GTRFEo6TCJ7sOnh7sn6s9QpZXsUNgEfhpNzgZrtl2wnAiTxATE6zwt\nUv7cRMKDs7yj9yXs2OmYq8lUlq2gsb72eJ2cgrf3qFnXZzyuVtsPzrlPFZJiEU3w\n0UQsYcLf1SnpN3OpZWVa+JWJCw79tH/ZfY38s69Ho94umTsEou8pjkXaUVxNu1b/\nXX82IB58Vw2wDYyHKIxt4M0lSm8mcf7H/oyTwQzUDvaGDF6zjkerDoYHR/mTippc\nuyxxe/5+PMJ+SnIhLfik+pmMvRsZDGlaFiB0ntMSpI9fqyEhdb9OSU8WvUAcXuMt\nAQD8sq4nqwFF/wIDAQABo4GJMIGGMB0GA1UdDgQWBBSQ1xMNvp9qhTq4DYzCcn/B\nfqC/GTBXBgNVHSMEUDBOgBSQ1xMNvp9qhTq4DYzCcn/BfqC/GaErpCkwJzElMCMG\nA1UEAxMcbGVlZHNzYW5kYm94LnJlYWxpemVnb2FsLmNvbYIJANezMu+9Ie8PMAwG\nA1UdEwQFMAMBAf8wDQYJKoZIhvcNAQEFBQADggEBAHBnMZVLcKsW3TekE5Haywjb\n+6DIliEEW7Ll2Dm6Obp0eUWCQEMFUM38u11cUNB0USIg2Msf3chiw0hdqjXWBFlC\nfthBLbenj4+gL8V95/5W9XAa+jd1YpW/Fdl8vqqnNMxjMc39SthB0cFpqN7Hi+aB\nglnE+/TIF5PgtjC9v8eWALaqz7cY+9r+m0Br3GWtucl3lg0VTx850I8oKsucBlHK\nrO/GyQlIv51phz8eYTFBn+LwbXZDHpE/4DFGoutaV4Fw1pVbBJZJzQmQeDXQ5dG+\n1UjZ191NN0G5uOdHVkWzKkWrojCeWgKWGTn3ctUwK6W531Wfj6M3gDGfRNk+6Vo=\n-----END CERTIFICATE-----\n",
      "xmlsec_privatekey" => "-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAKCAQEAl+DKdD2k9QlSmMT7J4GTRFEo6TCJ7sOnh7sn6s9QpZXsUNgE\nfhpNzgZrtl2wnAiTxATE6zwtUv7cRMKDs7yj9yXs2OmYq8lUlq2gsb72eJ2cgrf3\nqFnXZzyuVtsPzrlPFZJiEU3w0UQsYcLf1SnpN3OpZWVa+JWJCw79tH/ZfY38s69H\no94umTsEou8pjkXaUVxNu1b/XX82IB58Vw2wDYyHKIxt4M0lSm8mcf7H/oyTwQzU\nDvaGDF6zjkerDoYHR/mTippcuyxxe/5+PMJ+SnIhLfik+pmMvRsZDGlaFiB0ntMS\npI9fqyEhdb9OSU8WvUAcXuMtAQD8sq4nqwFF/wIDAQABAoIBAQCVQJ80ZG/7LdIx\nt0JprHigpnFh2AV00mmMhWvQ4TMLxq2ZNPAVTJwxXzXy3Vd1vygXdehek6Cm8zZb\njBwJQdSQSIDdGZKjHxM1kCNfCZ8FIT5xZ4DFvKRmG8foKxb5vDnvpQ8imkmSHUDQ\nQcXdoXZCvDM4Jcaki69FYtIH06xUKPUh/rESJ1e8OF6R1KbvM6TwLyP7v1iVmY2m\nFCTfJXPUXAhafW4gU0VEury0AK40fol+m4vThz9SzVW4kgyqX0PKFV80v+CW1aMt\noUoLXxPrdG5nEcrtDMvIfzrsauIYcNpeGY7Ci2p9/llLi3C+9ALXg3VdMStAdTRM\nuxMOn90hAoGBAMZnvgKOAsV3EQVICA4XF3H8lztp9XZjg3Gmz5NojCm+Hz4LyhF2\nnz9vGjbTyR2ioVG5M51CutgiAruhpsKbL/hWsLxHzp4r1BwpoftWMRv3sbQ3wzWb\np7f6E+kZGTuJ5XpgrlNLf+8amS7V1qh0VHbsUUX53KPfDzyzJVcxGwXVAoGBAMP3\nb8VkXilo0lTrDUuQAZoQ3LaxVoPqqeMpX6gIPPxDL0pDUxva8yiGICjQYiTUSsp6\nDSoU7g/ZXCQqWhH6jANcusnVTHp3iNG1HLUX2jD6A7CJhJ+JFGzmeOdeuUT+6yqE\nqKGpsdGL9uoD8kQSTQZi9kJVrBzZgPiLpP1GSyKDAoGAJHGN315CeA8E21l90UjA\nj7l79ffilJp23HttiYAcrtYzWuxDc628VqSLxiJkwMLMqvw/1NUbCPRGWDy7Kufi\nidUypYLzGu6mCX5EOKx+XMrEo3vSqZgr2Ilg+uIXVm5f7nivzLEDkOHr3UR+J3cm\nxKlnzFi3BIrGe7nUVA27DvkCgYEAoSVkICn81IiCDZqMgEqXRp3/IayKvEfIFCj9\npCvCGp8U0Di0qv9NXVGOOIHDcw2vwvjCwowbh6TyBDtffdFOOaWTZE2maj7Jn8kT\nJkfLAONXDWDIUnhi93o+ieR27anCsGAOW4Iz22EBVkaQfjGebVYLs1jIA6FIURpk\nPnIDbwkCgYBlWTEMLqdSuFVh36FFDMnOwPQ7wqINVfRalSPPbke0exA+q0vgVtug\n5c49X4MowNhyONI6EUzXgMN26+JrWPWE/Z8XwYQXeuvkHDIZpQYwRnwANawbZIO0\nBgfskwgEnHqJIduuJf17uFsUDd7iLyANfZAf+/75RX4WUPfNc093bQ==\n-----END RSA PRIVATE KEY-----\n",
      "friendly_name" => "eduPersonPrincipalName"
    }
  end

  def name_saml_options
    {
      "idp_sso_target_url" => "https://wildlife.secure.force.com/?RelayState=https://secure.chronus.com/session",
      "idp_cert_fingerprint" => "17fba32a30806b5536ceb4861611a31b95660272",
      "xmlsec_certificate" => "-----BEGIN CERTIFICATE-----\nMIIEqjCCA5KgAwIBAgIJALr7nVjhA4FNMA0GCSqGSIb3DQEBBQUAMIGUMQswCQYD\nVQQGEwJVUzEQMA4GA1UECBMHQXJpem9uYTETMBEGA1UEBxMKU2NvdHRzZGFsZTEV\nMBMGA1UEChMMQ2hyb251cyBDb3JwMQ8wDQYDVQQLEwZNZW50b3IxFjAUBgNVBAMU\nDSouY2hyb251cy5jb20xHjAcBgkqhkiG9w0BCQEWD29wc0BjaHJvbnVzLmNvbTAe\nFw0xMzA5MjMxNDIyMzBaFw0xNDA5MjMxNDIyMzBaMIGUMQswCQYDVQQGEwJVUzEQ\nMA4GA1UECBMHQXJpem9uYTETMBEGA1UEBxMKU2NvdHRzZGFsZTEVMBMGA1UEChMM\nQ2hyb251cyBDb3JwMQ8wDQYDVQQLEwZNZW50b3IxFjAUBgNVBAMUDSouY2hyb251\ncy5jb20xHjAcBgkqhkiG9w0BCQEWD29wc0BjaHJvbnVzLmNvbTCCASIwDQYJKoZI\nhvcNAQEBBQADggEPADCCAQoCggEBAO9oi6esxom5f5HRBmD/csqNqtLK9pxJl30H\n0/DDsMnDspAxUDE9d7MXyuIBQNMnDYX1ct0EDIujfmvsqzdbXWn/qWwJPBhw87C6\nVyOyct2Dtu3paMDWypduzelouPz6nGn/RNCr+xeJyjMhxg9wKGAxYcyu/4Dgun/Q\nHPKNNx15mqgkFSaacFIKc/HSG6MBCuyO2A+sJ43nVcuY6fgyCabVnwfZ+L/8zthP\nGthDl6MywgBJUXN/Ct2FDky/SUqUeyCBtaYYZC9rMD181Hn6lbU/EqJFT0JYhr2f\nFkHu5owwzIrI6ISbuuLFL6+BXjQ45CwYsXwMofmbiXEh+Z3rgdECAwEAAaOB/DCB\n+TAdBgNVHQ4EFgQUUiyvww7fh/IbKEQqst6Kts8sy3EwgckGA1UdIwSBwTCBvoAU\nUiyvww7fh/IbKEQqst6Kts8sy3GhgZqkgZcwgZQxCzAJBgNVBAYTAlVTMRAwDgYD\nVQQIEwdBcml6b25hMRMwEQYDVQQHEwpTY290dHNkYWxlMRUwEwYDVQQKEwxDaHJv\nbnVzIENvcnAxDzANBgNVBAsTBk1lbnRvcjEWMBQGA1UEAxQNKi5jaHJvbnVzLmNv\nbTEeMBwGCSqGSIb3DQEJARYPb3BzQGNocm9udXMuY29tggkAuvudWOEDgU0wDAYD\nVR0TBAUwAwEB/zANBgkqhkiG9w0BAQUFAAOCAQEAV+KpY7DyAGFRB+mGV9tmBDT/\nePqtH0HnUpjrKtF1RU9kHPNvnyxs2Si8LHFyomp5PM0Nc+WqCDKl9oSY7jvxvKfI\nxqoCwoWi+aMR2hVkKkcBWps8FS75QOkakh8BwIVNAiuT0GY0OnB7IF5k2EaTfPLM\niyJZIU3ubM4pg+CL1dk3TUiKvj9BetD3A+7gQOXVIvGKkQBLR+//WCMBAgBc6s9t\nHJDyPq2gNjzCArAfaHmt67BqV21U5px5QfNKsYmRbSwYF+j8lww8xHwcedhHOTn6\nxHIVOvUGA6Gd/vsQahZ+Pod9rbY20y/Ln4kdR55gv3WXVzYfqxvEe3B52edX+w==\n-----END CERTIFICATE-----\n",
      "xmlsec_privatekey" => "-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEA72iLp6zGibl/kdEGYP9yyo2q0sr2nEmXfQfT8MOwycOykDFQ\nMT13sxfK4gFA0ycNhfVy3QQMi6N+a+yrN1tdaf+pbAk8GHDzsLpXI7Jy3YO27elo\nwNbKl27N6Wi4/Pqcaf9E0Kv7F4nKMyHGD3AoYDFhzK7/gOC6f9Ac8o03HXmaqCQV\nJppwUgpz8dIbowEK7I7YD6wnjedVy5jp+DIJptWfB9n4v/zO2E8a2EOXozLCAElR\nc38K3YUOTL9JSpR7IIG1phhkL2swPXzUefqVtT8SokVPQliGvZ8WQe7mjDDMisjo\nhJu64sUvr4FeNDjkLBixfAyh+ZuJcSH5neuB0QIDAQABAoIBAD0poVwh+MrguCWh\nmBaZzFLRJI4byisdZfVMVaoR5I13UJwj7Q/XW0hG0M8ycMRBGuRZU5IBYc8e4sJh\nwVAwKEpXRYpTRaYc3TUONgrpoQzUhJx9YAS8Gx/a8AIsfe4rfGBcFdGVzl0yF5U+\nkKILDlWc6BZpst7TCvJyUaLpzuXZV9LcsFmhzcNn7Zmyx/c9vkbhLrtq9ocDWQxk\ncV2cYRKF5wj28WZJDe12HuC7S09T/sV9UohL1yRyMIE5+SGBNzW4v6mVvP12yIfP\nTQRbPrmu3Bqm2jt4jK2cRctYybvy2i6Tv+DZRdbph/vc6bxxD/CwT9xuhbY8Sadr\n26FNtAECgYEA/MYNAtm2uM653HM51cUi7AF2IPTAaPZGxvYrEHTGqsMy8ETvdfsp\nm8is3WnznliFXNB95woMLxP7uX9SiTqmwknxHEJMqWE/h2oV/i5+5AQr9aBGWyAJ\n+pYEYBzXLxVLKWdkb9VjW5T/mQly06KHX1zpBp+3o+zM0mktGzwqPsECgYEA8nbS\nuNlfFej3noyEpU5r7WZfYEt4oIxA22jsh+EeybytUOIL+ZlZQjiIn8NSb1Iebrhg\n492xT7Yg3vTN8XEHqH5+x84Z0nSydLlJ/NDG8znCEH4msa3JCH2E+m+LwEKclGw4\nOwaxG050RypU+RhLTKsZF00TC2bhdlAl30v6FxECgYAcYCtDv6b4dhR9P94lNj0m\nWz+kkXUsE0F8wlOxRDqtHr6QJFzxVKGmIE/vhx5XDz7hXXJUxlb5zfd7KmTcjN39\nf4l2j6bFeOpFzE3tu9B4zlMU/soHHsCgBck19ObfHTfTzQyEVWMS+9X5mwrt4Rfr\nR6XNHY7i8wlHMZFjtkxTwQKBgBuCt+4ZW9yUjmQC9Zn8B+rrzq6SYaF1yHYctZnF\nRUUGj3O58jnj2GjXGUlnVBclbiaJ7RRttwygUaJ6jFN0y7WmhKQPEob6jrUHwQla\ndvhp+Ub9yU4ntcOs2kXAGk86P6HnlYm8/KNoh3D7sKCCzShp0XL/X8XPao2OEn3/\nlOTBAoGBAO0owZMm9pdS4s5ap3C9la1LYDKrUxg6tiO9TVsOL1hJmTkA4MWibUMh\nS+cIBUgqFeEApEe5S9MHq4nDwDXjR9vfiIz29uqGZ1vFKO80XSZdBf1WYqFckm9b\ntbdlGrgxwxjPciMl9kcakEas5VVW0cLjQQIU2+55sHEY+xh99bN0\n-----END RSA PRIVATE KEY-----\n",
      "name_parser" => "username"
    }
  end

  def saml_options_with_idp_base64_cert
    {
      "idp_cert_fingerprint"=>"eb8c0abe54c4a8e3bec79cf965d30fdaee616acd",
      "idp_base64_cert"=>"MIICEjCCAXugAwIBAgIBCjANBgkqhkiG9w0BAQQFADAuMSwwKgYDVQQDEyN1c2ZyZC1zc29vYW0tdDEudGVzdC5pbnZpdHJvZ2VuLm5ldDAeFw0xNTA0MjExODA4MDdaFw0yNTA0MTgxODA4MDdaMC4xLDAqBgNVBAMTI3VzZnJkLXNzb29hbS10MS50ZXN0Lmludml0cm9nZW4ubmV0MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCiaELlwmok4QFfQjShqORyfWJTtEqhzeYC1uebQLSaF6VXKxDTIgH/YGgA50YesSkanh3W35pz4CDNx8maMK6ql5e8vXqw7R6TG2XntzHPne2/I2dXNsGKzvqntnFRYyRe4YuTHCFSGsGOY+rN3t/10oPRpOC1mV3KIadjjX6ynQIDAQABo0AwPjAMBgNVHRMBAf8EAjAAMA8GA1UdDwEB/wQFAwMH2AAwHQYDVR0OBBYEFEIhRYZsDXTNx7efXpR9C4CuCvRFMA0GCSqGSIb3DQEBBAUAA4GBAHMbj6gMR/hw1VoMyBCCDk/PxAMsetJz83Yh/GHNIvdSuKFc0jPAjlz+VaKOdLC0HGuBkeBpp57cEcwEWlrDRFq/paZnJDY5kndhS2/ahYp5EC9b4RFzCkBYKjDmgQiPNaaIDZJWJ/KKp6X8lTic8ThCFS0no8iemlo+xs1iK2AC",
      "xmlsec_privatekey"=>"-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQCX2CPf1fLNxeMb\nLLrPwYppIahwHOclcJMHGzzT9sv0aHOS9RqzH9zU9rNAsm3/OdcySRHgV896jZsD\n5+jHd7XwQG7adeDLhDrN4LFfXjkwizGrTIc3XEpo0Ie3PX4UgKUtTKHzewcA7jV+\nPXcgwHgPEhiwy1WRdEPAzpuDP8Fz4vicsvMQGozbVAIwBm7HgS4OcitJihA8LUF9\nCxH0vrQyxUIs/gTiyaZHa7eFnn64lYljLihv8QneuzEm1wucmZq/HoCgUgQIREGT\nwQt2pS/AdzqsQWOdTYybGy1MW6YWZrJ07OQZyRNQ8rrK629ZcWrl2amq7Ail3o+z\nnszBFTF5AgMBAAECggEASzw0yjtfysU5+cT36uiig+TBaItpnAtjTioYwY2PENKQ\nMUhwqkAnUv3JY00FY2htT+UUjmvzyW1QWWcW135hD2Fdi7DMaQpjeI7UU8SD4aGW\nQqHwfWWlGLn6BLjbN51mOkO2GsXienuM1bfuxrOWySDWSwL0qtVInMfCFg4I9DnG\nP4x8uUSJbh3diRas5xixLsaF71k/0hxsQD019jbmc+p6x26WDUTyTaepopNedjTY\nZtTc9XoSLgE2l5q09xZmFMkba3YjqMcJ2+PuSNlnDOLs3HPn7dgyKyZjDR6qeg+J\nHne6KI0dkZHdLSfEMibQPpXimdZhPqDq2+SlYJA8AQKBgQDH0hdcQaQQy20rLrpM\n5qrXhXerFFq0y11tQ95dP4ZPyOe7aFpgFBHnsSuVXg2gc3xB5T5qV7M0I7ZmsvKW\nPn0+QFnpXZEgX2RZOh+YjtJrWd2EZn/INyOF7sLU4vB8VftMAjCbVjvk2Of36U7I\nFEBSHXYvu7Mquefc3p33GM8m6QKBgQDCiP5iuoXaNExqmLHRClspIQq8VHlYMpd1\nI/jAKNoQ8zlNnKRroswutFG8R4C21sOD8mJ/47ZM/qpwUdMUCXHX1Z8QEPqrCBax\nxY908v02wno594s01XsyWqpZpUIbnkhvOwnKv5V1XqEhHX076RYVhg3RejhWiN00\n6C4r9W08EQKBgFXU6dHoJEhOiXMuHDpiLupq209ya9ATNutzZrXZTqFA5EF8/q0c\nkeBbGySLBQFx+eL4TMozJ7fyyyvsHAXri7LMw5JZbbhhIWKuc9n9J2eTb3Kq8KKZ\nBLpIKAp3/OL7r/kjS6u96/ZOMb4synlpMYPUQesZDkoBFxapzWLRllHZAoGAbiYL\ng/OBHtBGBIV5CZgHjf47ie961cmvoJBBpOx8rORLKfrrzlZbroZDUYxbASwRgICZ\n7TgOXQJFl1t9XPcMEt3ONtamWHk4AGiQlfOQFJWBh5j2pW/LVfOoSSIdkG3LLdAL\n91ULV23BZnLAGlAcRQumf1no1HaiafadTh6lP0ECgYAPnBAr91wM0VnuKqV5+Uag\nZbveSO11UKdecqV9HPrEqM3GRGpSNDJgbM23SCrFshsrjtSwC9ekoKAiLHmdlQTJ\neyZUj7Dd7RgCH2VUddcs/SPJdiwJgGiFCodwE2TRkS5T58ncNvt4nt1IxCW+hVQM\neY015meDFzFI+Upv8P0HGQ==\n-----END PRIVATE KEY-----\n",
      "xmlsec_certificate"=>"-----BEGIN CERTIFICATE-----\nMIIDpjCCAo4CCQCh1JvvrihpMTANBgkqhkiG9w0BAQUFADCBlDELMAkGA1UEBhMC\nVVMxEDAOBgNVBAgTB0FyaXpvbmExEzARBgNVBAcTClNjb3R0c2RhbGUxFTATBgNV\nBAoTDENocm9udXMgQ29ycDEPMA0GA1UECxMGTWVudG9yMRYwFAYDVQQDFA0qLmNo\ncm9udXMuY29tMR4wHAYJKoZIhvcNAQkBFg9vcHNAY2hyb251cy5jb20wHhcNMTYw\nODMxMTc1NDU2WhcNMjYwODI5MTc1NDU2WjCBlDELMAkGA1UEBhMCVVMxEDAOBgNV\nBAgTB0FyaXpvbmExEzARBgNVBAcTClNjb3R0c2RhbGUxFTATBgNVBAoTDENocm9u\ndXMgQ29ycDEPMA0GA1UECxMGTWVudG9yMRYwFAYDVQQDFA0qLmNocm9udXMuY29t\nMR4wHAYJKoZIhvcNAQkBFg9vcHNAY2hyb251cy5jb20wggEiMA0GCSqGSIb3DQEB\nAQUAA4IBDwAwggEKAoIBAQCX2CPf1fLNxeMbLLrPwYppIahwHOclcJMHGzzT9sv0\naHOS9RqzH9zU9rNAsm3/OdcySRHgV896jZsD5+jHd7XwQG7adeDLhDrN4LFfXjkw\nizGrTIc3XEpo0Ie3PX4UgKUtTKHzewcA7jV+PXcgwHgPEhiwy1WRdEPAzpuDP8Fz\n4vicsvMQGozbVAIwBm7HgS4OcitJihA8LUF9CxH0vrQyxUIs/gTiyaZHa7eFnn64\nlYljLihv8QneuzEm1wucmZq/HoCgUgQIREGTwQt2pS/AdzqsQWOdTYybGy1MW6YW\nZrJ07OQZyRNQ8rrK629ZcWrl2amq7Ail3o+znszBFTF5AgMBAAEwDQYJKoZIhvcN\nAQEFBQADggEBAITO2V9iAa48qrh2uWd7yZ1NSsF2t0vpRfz6sDe5GUT4fOUNK1Lt\n9/U+zF6MKZTL9XpkubWshVOgCrRu2lGfrHhROagxRhASMlASj21wpqcmIsjb9PmN\nm7RoYt+pf4vcyVnIsATYnF/zeDwbPQvlg/agvLpPr/DGLmNb24x/xf05XICiFZq4\nBx1RSfgBMqOjp9dyeWzkY5Lluut0f4gPCTCBRcasUW0BZXaO1tui35bGRs7atPGT\nAj1y4RX3nPeUiOAMNY0O80mtVmyCbOaMj6L7Hrw/7lpDW0l1PxGClqdNEZwe5ZO/\ni4sDTc/qNUdDADZgxbOPB/Br/JHFoASjF0E=\n-----END CERTIFICATE-----\n",
      "xmlsec_privatekey_pwd"=>"ZFzX8wsuIRx6N8RrC0GsLA"
    }
  end
end