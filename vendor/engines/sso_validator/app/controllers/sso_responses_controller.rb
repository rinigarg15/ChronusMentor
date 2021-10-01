class SsoResponsesController < ApplicationController
  skip_before_action :verify_authenticity_token, :only => :create
  skip_before_action :handle_terms_and_conditions_acceptance
  skip_before_action :login_required_in_program, :require_program, :back_mark_pages, :handle_pending_profile_or_unanswered_required_qs

  allow :exec => :can_access_sso_validator

  def index
    @prog_or_org = @current_organization
    @auth_configs = @prog_or_org.auth_configs
    @urls = []

    @auth_configs.each do |ac|
      case ac.auth_type
      when AuthConfig::Type::BBNC
        @urls << {
          text: AuthConfig::Type::BBNC,
          url: get_bbnc_auth_url(ac),
          method: :get
        }
      when AuthConfig::Type::OPENSSL
        @urls << {
          text: AuthConfig::Type::OPENSSL,
          url: get_openssl_auth_url(ac),
          method: :get
        }
      when AuthConfig::Type::LDAP
        @urls << {
          text: AuthConfig::Type::LDAP,
          url: get_ldap_auth_url(ac),
          method: :post
        }
      end
    end

  end

  private

  def can_access_sso_validator
    (Rails.env.development? || Rails.env.staging?) && !current_member && super_console?
  end

  def get_bbnc_auth_url(ac)
    options = ac.get_options
    private_key = options["private_key"]

    uid = 'ramya@chronus.com'
    ts = Time.now.to_s

    sig = Digest::MD5.hexdigest(uid + ts + private_key)

    return new_session_url({auth_config_id: ac.id, userid: uid, ts: ts, sig: sig})
  end

  def get_openssl_auth_url(ac)
    ssh_public_key = "-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA3PVuDbeAeY8EZkP3iKeR
4Lvts8pXEV+qwxhuW9R/FRnbzxVbAH8CVbaR98jKuFXzO3hYJGwYgaOxtjikAt9w
Ng6jMGcyO5eDlhP2pOsc+32cxa7g+pR+txvnHotU3tYhT3bT4eZhascch4ayvBBD
VzF5L27R7dgacBY1V4QvK1WOKi3iqnSjwtqZlx3SbXq3d2zx1V8YGnAVE/1rqg6e
SVgG1wG4jHoJI2uCHB/BLOjFnJBFN6s9MAdyNUOA8U8rNuiszs3yP3W6BwIlJS1i
BGBj+fkk4TIXcihKy7Ef4XCqggxC1KzRSOc/SgCEKKpjwb2l3BStQAqM8l5o3j8R
cwIDAQAB
-----END PUBLIC KEY-----"

    email = 'ramya@chronus.com'
    rsa = RsaHelper::CryptEngine.new(ssh_public_key, ssh_public_key)
    login_data = rsa.encrypt(email)
    return new_session_path({auth_config_id: ac.id, login_data: login_data})
  end

  def get_ldap_auth_url(ac)
    options = ac.get_options
    login_name = "tesla"
    password = "password"
    return session_path({auth_config_id: ac.id, email: login_name, password: password})
  end
end
