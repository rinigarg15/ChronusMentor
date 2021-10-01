require_relative './../../../test_helper'

class SOAPAuthTest < ActiveSupport::TestCase

  def test_integrity
    base_directory = File.join(Rails.root.to_s, "app/files/SOAPAuth")
    child_directories = Dir.entries(base_directory).select { |entry| File.directory? File.join(base_directory, entry) }
    child_directories.reject! { |directory| directory == "." || directory == ".." }

    expected_digest = YAML::load(File.read(File.join(base_directory, "digest.yml")))
    child_directories.each do |directory|
      assert expected_digest[directory], `find #{File.join(base_directory, directory)} -type f | sort -u | xargs cat | md5sum`.split[0]
    end
  end

  def test_authenticate_token_based
    soap_auth_config, options = setup_soap_auth_config
    assert soap_auth_config.token_based_soap_auth?
    auth_obj = ProgramSpecificAuth.new(soap_auth_config, ["user_name", "password"])

    SOAPAuth.expects(:login).once.returns( { "uid" => "12345", "nftoken" => "45678" } )
    SOAPAuth.expects(:validate).never
    SOAPAuth.expects(:logout).never
    SOAPAuth.expects(:validate_member).never
    assert_equal true, SOAPAuth.authenticate?(auth_obj, options)
    assert_equal "12345", auth_obj.uid
    assert_equal "45678", auth_obj.nftoken
  end

  def test_authenticate_not_token_based
    options = get_options
    options["get_token_url"] = nil
    soap_auth_config = AuthConfig.new(auth_type: AuthConfig::Type::SOAP, organization: programs(:org_primary))
    soap_auth_config.set_options!(options)
    assert_false soap_auth_config.token_based_soap_auth?
    auth_obj = ProgramSpecificAuth.new(soap_auth_config, ["user_name", "password"])

    SOAPAuth.expects(:login).once.returns( { "uid" => "12345", "nftoken" => "45678" } )
    SOAPAuth.expects(:validate).never
    SOAPAuth.expects(:logout).never
    SOAPAuth.expects(:validate_member).never
    assert_equal true, SOAPAuth.authenticate?(auth_obj, options)
    assert_equal "12345", auth_obj.uid
    assert_nil auth_obj.nftoken
  end

  def test_authenticate_already_logged_in
    soap_auth_config, options = setup_soap_auth_config
    auth_obj = ProgramSpecificAuth.new(soap_auth_config, [:logged_in_already, "uid"])

    SOAPAuth.expects(:login).never
    SOAPAuth.expects(:validate).never
    SOAPAuth.expects(:logout).never
    SOAPAuth.expects(:validate_member).never
    assert_equal true, SOAPAuth.authenticate?(auth_obj, options)
    assert_equal "uid", auth_obj.uid
    assert_nil auth_obj.nftoken
    assert_nil auth_obj.has_data_validation
    assert_nil auth_obj.is_data_valid
    assert_nil auth_obj.permission_denied_message
    assert_nil auth_obj.prioritize_validation
  end

  def test_import_data
    options = get_options
    options["get_token_url"] = nil

    options.merge!({"import_data" =>  {"attributes"=>{"Member"=>{"first_name"=>"first_name", "last_name"=>"last_name", "email"=>"email"}}}})
    soap_auth_config = AuthConfig.new(auth_type: AuthConfig::Type::SOAP, organization: programs(:org_primary))
    soap_auth_config.set_options!(options)
    assert_false soap_auth_config.token_based_soap_auth?
    auth_obj = ProgramSpecificAuth.new(soap_auth_config, ["user_name", "password"])

    SOAPAuth.expects(:login).once.returns( { "uid" => "12345", "first_name" => "Test", "last_name" => "Last", "email" => "abc@example.com" } )
    SOAPAuth.expects(:validate).never
    SOAPAuth.expects(:logout).never
    SOAPAuth.expects(:validate_member).never

    assert_equal true, SOAPAuth.authenticate?(auth_obj, options)
    assert_equal "12345", auth_obj.uid
    expected_hash = {"Member"=>{"first_name"=>"Test", "last_name"=>"Last", "email"=>"abc@example.com"} }
    assert_equal expected_hash, auth_obj.import_data
    assert_nil auth_obj.nftoken
  end

  def test_authenticate_already_logged_in_with_validations
    options = get_options
    options["validate"] = {
      "criterias" => [ {
        "criteria" => [ {
          "attribute" => "is_member",
          "operator" => "eq",
          "value" => "1"
        } ],
      } ],
      "fail_message" => "Permission Denied",
      "prioritize" => true
    }
    soap_auth_config = AuthConfig.new(auth_type: AuthConfig::Type::SOAP, organization: programs(:org_primary))
    soap_auth_config.set_options!(options)
    auth_obj = ProgramSpecificAuth.new(soap_auth_config, [:logged_in_already, "uid"])

    SOAPAuth.expects(:login).never
    SOAPAuth.expects(:validate).never
    SOAPAuth.expects(:logout).never
    SOAPAuth.expects(:validate_member).once.returns( { "is_member" => "1" } )
    assert_equal true, SOAPAuth.authenticate?(auth_obj, options)
    assert_equal "uid", auth_obj.uid
    assert_nil auth_obj.nftoken
    assert auth_obj.has_data_validation
    assert auth_obj.is_data_valid
    assert_equal "Permission Denied", auth_obj.permission_denied_message
    assert_equal true, auth_obj.prioritize_validation
  end

  def test_authenticate_failue
    soap_auth_config, options = setup_soap_auth_config
    auth_obj = ProgramSpecificAuth.new(soap_auth_config, ["user_name", "password"])

    SOAPAuth.expects(:login).once.returns(false)
    SOAPAuth.expects(:validate).never
    SOAPAuth.expects(:logout).never
    SOAPAuth.expects(:validate_member).never
    assert_false SOAPAuth.authenticate?(auth_obj, options)
    assert_nil auth_obj.uid
    assert_nil auth_obj.nftoken
  end

  def test_authenticate_failure_empty_guid
    soap_auth_config, options = setup_soap_auth_config
    auth_obj = ProgramSpecificAuth.new(soap_auth_config, ["user_name", "password"])

    SOAPAuth.expects(:login).once.returns( { "uid" => "00000000-0000-0000-0000-000000000000", "nftoken" => "45678" } )
    SOAPAuth.expects(:validate).never
    SOAPAuth.expects(:logout).never
    SOAPAuth.expects(:validate_member).never
    assert_false SOAPAuth.authenticate?(auth_obj, options)
    assert_nil auth_obj.uid
    assert_nil auth_obj.nftoken
  end

  def test_authenticate_already_logged_in_failure
    soap_auth_config, options = setup_soap_auth_config
    auth_obj = ProgramSpecificAuth.new(soap_auth_config, [:logged_in_already, ""])

    SOAPAuth.expects(:login).never
    SOAPAuth.expects(:validate).never
    SOAPAuth.expects(:logout).never
    SOAPAuth.expects(:validate_member).never
    assert_false SOAPAuth.authenticate?(auth_obj, options)
    assert_nil auth_obj.uid
    assert_nil auth_obj.nftoken
  end

  def test_login
    options = get_options
    input_params = { "input" => "param" }
    SOAPAuth.expects(:execute_sequence).with(options["login_sequence"], options["setup"], input_params).once
    SOAPAuth.expects(:execute_sequence).with(options["validate_sequence"], options["setup"], input_params).never
    SOAPAuth.expects(:execute_sequence).with(options["validate_member_sequence"], options["setup"], input_params).never
    SOAPAuth.expects(:execute_sequence).with(options["logout_sequence"], options["setup"], input_params).never
    SOAPAuth.login(options, input_params)
  end

  def test_validate
    options = get_options
    input_params = { "input" => "param" }
    SOAPAuth.expects(:execute_sequence).with(options["login_sequence"], options["setup"], input_params).never
    SOAPAuth.expects(:execute_sequence).with(options["validate_sequence"], options["setup"], input_params).once
    SOAPAuth.expects(:execute_sequence).with(options["validate_member_sequence"], options["setup"], input_params).never
    SOAPAuth.expects(:execute_sequence).with(options["logout_sequence"], options["setup"], input_params).never
    SOAPAuth.validate(options, input_params)
  end

  def test_validate_member
    options = get_options
    input_params = { "input" => "param" }
    SOAPAuth.expects(:execute_sequence).with(options["login_sequence"], options["setup"], input_params).never
    SOAPAuth.expects(:execute_sequence).with(options["validate_sequence"], options["setup"], input_params).never
    SOAPAuth.expects(:execute_sequence).with(options["validate_member_sequence"], options["setup"], input_params).once
    SOAPAuth.expects(:execute_sequence).with(options["logout_sequence"], options["setup"], input_params).never
    SOAPAuth.validate_member(options, input_params)
  end

  def test_logout
    options = get_options
    input_params = { "input" => "param" }
    SOAPAuth.expects(:execute_sequence).with(options["login_sequence"], options["setup"], input_params).never
    SOAPAuth.expects(:execute_sequence).with(options["validate_sequence"], options["setup"], input_params).never
    SOAPAuth.expects(:execute_sequence).with(options["validate_member_sequence"], options["setup"], input_params).never
    SOAPAuth.expects(:execute_sequence).with(options["logout_sequence"], options["setup"], input_params).once
    SOAPAuth.logout(options, input_params)
  end

  def test_execute_sequence_when_output_is_not_hash
    options = get_options
    input_params = { "input" => "param" }
    SOAPAuth.expects(:make_soap_call).returns(true).once
    assert_equal true, SOAPAuth.login(options, input_params)
  end

  def test_execute_sequence_when_output_is_hash
    options = get_options
    input_params = { "input" => "param" }
    SOAPAuth.expects(:make_soap_call).returns({}).twice
    assert_equal_hash({}, SOAPAuth.login(options, input_params))
  end

  def test_is_uid_valid
    soap_auth_config, options = setup_soap_auth_config
    options["empty_guid"] = 0
    soap_auth_config.set_options!(options)
    assert_false SOAPAuth.is_uid_valid?("0", options)
  end

  private

  def get_options
    {
      "setup" => { "wsdl_path" => "", "base_params" => {} },
      "get_token_url" => "www.chronus.com",
      "set_token_url" => "www.chronus.com",
      "empty_guid" => "00000000-0000-0000-0000-000000000000",
      "login_sequence" => {
        "execute_method" => { "request" => "", "response" => "" },
        "web_web_user_login" => { "request" => "", "response" => "" }
      },
      "validate_sequence" => {
        "web_validate" => { "request" => "", "response" => "" }
      },
      "validate_member_sequence" => {
        "get_individual_information" => { "request" => "", "response" => "" }
      },
      "logout_sequence" => {
        "web_logout" => { "request" => "" }
      }
    }
  end

  def setup_soap_auth_config
    soap_auth_config = AuthConfig.new(auth_type: AuthConfig::Type::SOAP, organization: programs(:org_primary))
    soap_auth_config.set_options!(get_options)
    [soap_auth_config, get_options]
  end
end