require_relative './../../../test_helper'

class LDAPAuthTest < ActiveSupport::TestCase
  
  def test_authenticate_success
    options = get_options
    res = {"bind" => [:authenticated_user], "operation_result" => "Success"}
    mock_ldap_call(res, options)
    auth_obj = ProgramSpecificAuth.new(programs(:org_primary).auth_configs.first, ["user_name", "password"])    
    assert LDAPAuth.authenticate?(auth_obj, options)
    assert_equal "user_name", auth_obj.uid
  end

  def test_authenticate_failure
    options = get_options
    res = {"bind" => false, "operation_result" => "Failure"}
    mock_ldap_call(res, options)
    auth_obj = ProgramSpecificAuth.new(programs(:org_primary).auth_configs.first, ["user_name", "wrong_password"])    
    assert_false LDAPAuth.authenticate?(auth_obj, options)
    assert_equal "user_name", auth_obj.uid
    assert_equal "Failure", auth_obj.error_message
  end

  def test_authenticate_no_user
    options = get_options
    res = {"bind" => false, "operation_result" => "Success"}
    mock_ldap_call(res, options)
    auth_obj = ProgramSpecificAuth.new(programs(:org_primary).auth_configs.first, ["user_name", "wrong_password"])    
    assert_false LDAPAuth.authenticate?(auth_obj, options)
    assert_equal "user_name", auth_obj.uid
    assert_equal "User not found", auth_obj.error_message
  end

  def test_authenticate_secure_failure
    options = get_options(:secure => true)
    res = {"bind" => [:authenticated_user], "operation_result" => "Success"}
    mock_ldap_call(res, options)
    auth_obj = ProgramSpecificAuth.new(programs(:org_primary).auth_configs.first, ["user_name", "password"])    
    assert LDAPAuth.authenticate?(auth_obj, options)
    assert_equal "user_name", auth_obj.uid
  end

  def test_authenticate_secure_ca_success
    options = get_options(:secure => true, :ca_cert => true)
    res = {"bind" => [:authenticated_user], "operation_result" => "Success"}
    mock_ldap_call(res, options)
    auth_obj = ProgramSpecificAuth.new(programs(:org_primary).auth_configs.first, ["user_name", "password"])    
    assert LDAPAuth.authenticate?(auth_obj, options)
    assert_equal "user_name", auth_obj.uid
  end

  def get_options(args={})
    options = {
      "host" => "server", 
      "port" => 389, 
      "base" => "base",
      "binding_auth"=> { :method => :simple, :username => "binding_username", :password => "binding_password"},
      "dn_attribute" => "username_attr"
    }
    options["secure"] = true if args[:secure]
    options["cert_store"] = "-----BEGIN CERTIFICATE-----
MIID0DCCArigAwIBAgIBADANBgkqhkiG9w0BAQUFADA8MQswCQYDVQQGDAJKUDES
MBAGA1UECgwJSklOLkdSLkpQMQwwCgYDVQQLDANSUlIxCzAJBgNVBAMMAkNBMB4X
DTA0MDEzMDAwNDIzMloXDTM2MDEyMjAwNDIzMlowPDELMAkGA1UEBgwCSlAxEjAQ
BgNVBAoMCUpJTi5HUi5KUDEMMAoGA1UECwwDUlJSMQswCQYDVQQDDAJDQTCCASIw
DQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANbv0x42BTKFEQOE+KJ2XmiSdZpR
wjzQLAkPLRnLB98tlzs4xo+y4RyY/rd5TT9UzBJTIhP8CJi5GbS1oXEerQXB3P0d
L5oSSMwGGyuIzgZe5+vZ1kgzQxMEKMMKlzA73rbMd4Jx3u5+jdbP0EDrPYfXSvLY
bS04n2aX7zrN3x5KdDrNBfwBio2/qeaaj4+9OxnwRvYP3WOvqdW0h329eMfHw0pi
JI0drIVdsEqClUV4pebT/F+CPUPkEh/weySgo9wANockkYu5ujw2GbLFcO5LXxxm
dEfcVr3r6t6zOA4bJwL0W/e6LBcrwiG/qPDFErhwtgTLYf6Er67SzLyA66UCAwEA
AaOB3DCB2TAPBgNVHRMBAf8EBTADAQH/MDEGCWCGSAGG+EIBDQQkFiJSdWJ5L09w
ZW5TU0wgR2VuZXJhdGVkIENlcnRpZmljYXRlMB0GA1UdDgQWBBRJ7Xd380KzBV7f
USKIQ+O/vKbhDzAOBgNVHQ8BAf8EBAMCAQYwZAYDVR0jBF0wW4AUSe13d/NCswVe
31EiiEPjv7ym4Q+hQKQ+MDwxCzAJBgNVBAYMAkpQMRIwEAYDVQQKDAlKSU4uR1Iu
SlAxDDAKBgNVBAsMA1JSUjELMAkGA1UEAwwCQ0GCAQAwDQYJKoZIhvcNAQEFBQAD
ggEBAIu/mfiez5XN5tn2jScgShPgHEFJBR0BTJBZF6xCk0jyqNx/g9HMj2ELCuK+
r/Y7KFW5c5M3AQ+xWW0ZSc4kvzyTcV7yTVIwj2jZ9ddYMN3nupZFgBK1GB4Y05GY
MJJFRkSu6d/Ph5ypzBVw2YMT/nsOo5VwMUGLgS7YVjU+u/HNWz80J3oO17mNZllj
PvORJcnjwlroDnS58KoJ7GDgejv3ESWADvX1OHLE4cRkiQGeLoEU4pxdCxXRqX0U
PbwIkZN9mXVcrmPHq8MWi4eC/V7hnbZETMHuWhUoiNdOEfsAXr3iP4KjyyRdwc7a
d/xgcK06UVQRL/HbEYGiQL056mc=
-----END CERTIFICATE-----
" if args[:ca_cert]
    options
  end

end