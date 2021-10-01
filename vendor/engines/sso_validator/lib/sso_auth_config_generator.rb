class SsoAuthConfigGenerator

  def self.create_bbnc(org)
    ac = org.auth_configs.where(auth_type: AuthConfig::Type::BBNC).first
    ac ||= AuthConfig.new
    
    ac.organization_id = org.id
    ac.title      = AuthConfig::Type::BBNC
    ac.auth_type  = AuthConfig::Type::BBNC
    ac.use_email = true;
    options = {}
    options["private_key"] = 'sso-validator-key'
    options["url"] = 'http://chronus.com'
    ac.set_options!(options)
  end

  def self.create_openssl(org)
  ssh_private_key = "-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA3PVuDbeAeY8EZkP3iKeR4Lvts8pXEV+qwxhuW9R/FRnbzxVb
AH8CVbaR98jKuFXzO3hYJGwYgaOxtjikAt9wNg6jMGcyO5eDlhP2pOsc+32cxa7g
+pR+txvnHotU3tYhT3bT4eZhascch4ayvBBDVzF5L27R7dgacBY1V4QvK1WOKi3i
qnSjwtqZlx3SbXq3d2zx1V8YGnAVE/1rqg6eSVgG1wG4jHoJI2uCHB/BLOjFnJBF
N6s9MAdyNUOA8U8rNuiszs3yP3W6BwIlJS1iBGBj+fkk4TIXcihKy7Ef4XCqggxC
1KzRSOc/SgCEKKpjwb2l3BStQAqM8l5o3j8RcwIDAQABAoIBACRzDCuRGM10rTod
fij505OqDKU6/K/uAyJZ1mKppCkb8emwUSm8yerPyjaA1gggjZZC3O9tMYG5Oiig
IVYj+8O/GGZ0r5GrBdbtBiPgcRB/gSwPFCfh9SFJpg+g1mhIFIiiRoOeWHWf0PH+
Y1+ooyMwExijBFhi7MGOuE/ui0VvcgPVnvp6m+6WwRj7D6yGJRnt5oMHKsV4jEkj
/kYhaWQcTFdJQVrh5w0lmukUJ5uKcvOcju/bn+ulCYtPQOMuvZ6X1vvMyv35zQ/x
LIZS8fshHHZuCZ0qf+SwbthKtcPH/XZ5jZiYpe20OFbEOoiZHNBXU6AlQYn7IJci
572dP/ECgYEA+5C47FW0NM6EbAovEEAf5A0l79OJq69y9HS27RYZhgXXgyVR/S+5
a6hV3HJGwD6MrlfynVbRULEq8NgsEPjEE6rAQLGggJL6Fjb93B8kday9fTguEDpa
6s85BkIl02FYvUtJFYR2ChF1azJArKXujtGhuLpvYPN/u89JGqfkNgkCgYEA4NqV
mN2I5SJyvjETZiT5/DabxTMeVnOr75bQrb6ovUxLY/MZWfD08tgzaTeLdd47iyF8
qDlB7gdBuyhEZncMaS/SAHmgvq9slCqb9zLlg9exf2gPOr9SkTkONEyyuVgCfaX8
LA4GFJ3nFro5qowYdOH+I17D+He30XxqIPLGCpsCgYEA+Y3OtLwsYXpBCUBtAazr
NfsJGEl8N/F7kx+5W6ZhuX9QFIxQMl9GjJLYYjCHGSyzuDwMtKKsUGUAmR2JUWjG
clAgGc1b0FB9gM4atWO7cnTjITY7E+QfzvG0uw2honjeZCIsJQlbY4+AMNAQMnUF
G27ABJYF6WKE41W1SpkknakCgYBFKFXMr46UUxURlEyQJR1SSoV8kK1rD6a5SRyj
47lIh7fEZRfOBwN/0al2WiQlu5V6xHDv2LSDfm3kH41yKnmBvLiNdttO6uutYrGX
xWq8M1IfiqTsf73odrD8uv5ZbU1O0geOkT2jh7F01xA3eWFoSb39qP8DY+cAopCN
072/swKBgQDK07tF7T66iXXPfTrakGxhd4eddOOxWh1s/ioC+V92yTJt62TIkV0T
+XOi4kg9wish6UcL+WPzvQqTNMBk/iEPhw7ZCgXsuxsGtipbeV7bk9Bo4IJrhdFw
pqnZ71Sy1tPOkVMHMfNSWIXxErZOaIp4vz0ldVGvztOogh131O3kTA==
-----END RSA PRIVATE KEY-----"
    ac = org.auth_configs.where(auth_type: AuthConfig::Type::OPENSSL).first
    ac ||= AuthConfig.new
    
    ac.organization_id = org.id
    ac.title      = AuthConfig::Type::OPENSSL
    ac.auth_type  = AuthConfig::Type::OPENSSL
    ac.use_email  = true

    options = {}
    options["private_key"] = ssh_private_key
    options["url"] = 'http://chronus.com'
    ac.set_options!(options)
  end

  # Usage: http://www.forumsys.com/tutorials/integration-how-to/ldap/online-ldap-test-server
  def self.create_ldap(org)
    ac = org.auth_configs.where(auth_type: AuthConfig::Type::LDAP).first
    ac ||= AuthConfig.new
    
    ac.organization_id = org.id
    ac.title      = AuthConfig::Type::LDAP
    ac.auth_type  = AuthConfig::Type::LDAP

    # member.login_name is the uid for this.
    # password is "password"
    # uid examples: ["tesla", "einstein", "euclid", "euler"]
    ac.use_email = false;
    
    options = {}

    options["host"]         = "ldap.forumsys.com"
    options["port"]         = 389
    options["dn_attribute"] = 'uid'
    options["base"]         = "dc=example,dc=com"
    options["binding_auth"] = {:method => :anonymous}
    
    ac.set_options!(options)
  end
end