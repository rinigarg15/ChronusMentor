require_relative './../../test_helper.rb'

class NotifyTest < ActiveSupport::TestCase
  include SamlAutomatorUtils

  def test_facilitation_messages
    deliver_count = 0
    mentoring_connections_v2_enabled_prog = programs(:pbe)
    mentoring_connections_v2_enabled_prog.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, false)
    Program.any_instance.expects(:deliver_facilitation_messages_v2).never
    Notify.facilitation_messages

    mentoring_connections_v2_enabled_prog.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, true)
    Program.active.map { |prog| deliver_count += 1 if prog.mentoring_connections_v2_enabled? }
    Program.any_instance.expects(:deliver_facilitation_messages_v2).times(deliver_count)
    Notify.facilitation_messages

    Airbrake.expects(:notify).times(deliver_count)
    Program.any_instance.expects(:deliver_facilitation_messages_v2).times(deliver_count).raises(RuntimeError, "Error")
    Notify.facilitation_messages
  end

  def test_admins_weekly_status
    deliver_count = 0
    active_programs = Program.active
    active_programs.map {|program| deliver_count += program.admin_users.active.count if program.should_send_admin_weekly_status? }
    AdminWeeklyStatus.any_instance.expects(:admin_weekly_status).times(deliver_count)
    Notify.admins_weekly_status

    AdminWeeklyStatus.any_instance.expects(:admin_weekly_status).never
    Notify.admins_weekly_status
  end

  def test_admin_weekly_saml_sso_check
    org = programs(:org_primary)
    InternalMailer.any_instance.expects(:saml_sso_expire).never
    Notify.admin_weekly_saml_sso_check

    stub_saml_sso_files(org.id)
    SamlAutomatorUtils.setup_saml_auth_config(org)
    ac = org.auth_configs.find_by(auth_type: AuthConfig::Type::SAML)
    ac.set_options!({"authn_signed" => true, "xmlsec_certificate"=>"-----BEGIN CERTIFICATE-----\nMIIDpjCCAo4CCQCK0hY5T/4PLzANBgkqhkiG9w0BAQUFADCBlDELMAkGA1UEBhMC\nVVMxEDAOBgNVBAgTB0FyaXpvbmExEzARBgNVBAcTClNjb3R0c2RhbGUxFTATBgNV\nBAoTDENocm9udXMgQ29ycDEPMA0GA1UECxMGTWVudG9yMRYwFAYDVQQDFA0qLmNo\ncm9udXMuY29tMR4wHAYJKoZIhvcNAQkBFg9vcHNAY2hyb251cy5jb20wHhcNMTUx\nMDE5MDkwMjA4WhcNMjUxMDE2MDkwMjA4WjCBlDELMAkGA1UEBhMCVVMxEDAOBgNV\nBAgTB0FyaXpvbmExEzARBgNVBAcTClNjb3R0c2RhbGUxFTATBgNVBAoTDENocm9u\ndXMgQ29ycDEPMA0GA1UECxMGTWVudG9yMRYwFAYDVQQDFA0qLmNocm9udXMuY29t\nMR4wHAYJKoZIhvcNAQkBFg9vcHNAY2hyb251cy5jb20wggEiMA0GCSqGSIb3DQEB\nAQUAA4IBDwAwggEKAoIBAQCaKH4lucss8UPpIplLbXxloTbgJMsqHgCry4DWLW3+\nOEUW0mUWKFJ88ZpY+kk0gvAVXY2kDo/KlhbJ8jbygAqW3TKpQ+AtKiDu930Bx9D6\nsgWPPdl1XCGhWExuG2exnjruMmd2ixf/4EFzGdj5GGwlw5TZYPtYlJT0ou1qkr7X\n+Wxl0sddrTr+vmUezKYCSrq8ARoe8toBJddNm2P2HvczuE2e2I83d00wHButLG2m\niNhHHuiizR07p5eLMLbSt5l6LmM+KDFPD/3x77I0MSLAoPEiCyEB1q6dcqamRSJu\niya931HflitOSyC8AEP9bZ67tf8EmirLwKa0VfhqBtw/AgMBAAEwDQYJKoZIhvcN\nAQEFBQADggEBAHTVfLDRzT7Ey15treXJ6jfT9dpaglCwgAhfeIXg0bZ10KXP3JC6\nK5KAMxGiYPIDiC1adCnAxdPwj25ThYNmWb3K7V5yIn9XlVMT3kGmkQHyI0+5MnfK\nTvnFznsUeC05fyw50OHH1jKwFzRjjA6yp5BhAn5P6AfPPs9fmtSfstO3EXzYqG2R\ngTydizP2+tIpISqASVo6D788fK8yW5LbKsfUkq3kLzSb9cfPrfYDPgen3YB2sQ4n\nX4c0smFTzPKR/Pe5WbQvxJWf0kpzg/uWK4kzMfgPwzE2FtVC4yqlr80f9xHXh/QH\n9nut8QqnVda7QBhAQlOcghgFhxbO0UjE6hc=\n-----END CERTIFICATE-----\n"})
    OpenSSL::X509::Certificate.any_instance.stubs(:not_after).returns(10.weeks.from_now.utc)
    InternalMailer.any_instance.expects(:saml_sso_expire).times(1)
    Notify.admin_weekly_saml_sso_check
  end
end