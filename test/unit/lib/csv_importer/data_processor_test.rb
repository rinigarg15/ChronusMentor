require_relative './../../../test_helper'

class CsvImporter::DataProcessorTest < ActiveSupport::TestCase
  def setup
    super
    @user_csv_import = UserCsvImport.new
    @user_csv_import.stubs(:local_csv_file_path).returns("test/fixtures/files/csv_import.csv")
    @user_csv_import.stubs(:id).returns(777)
    @col_mapping = {:email => UserCsvImport::CsvMapColumns::EMAIL.to_sym, :fname => UserCsvImport::CsvMapColumns::FIRST_NAME.to_sym, :lname => UserCsvImport::CsvMapColumns::LAST_NAME.to_sym, :role => UserCsvImport::CsvMapColumns::ROLES.to_sym, :uuid => UserCsvImport::CsvMapColumns::UUID.to_sym}
    @user_csv_import.stubs(:csv_column_to_field_mapping).returns(@col_mapping)
    @filename = "test/fixtures/files/csv_import.csv"
    @organization = programs(:org_primary)
    @program = programs(:albers)
    @options = {:program => @program, :column_mapping => {}, :cannot_add_organization_members => true, :role_names => [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], :profile_questions => @organization.profile_questions.except_email_and_name_question}
  end

  def test_valid_file
    error = assert_raise(RuntimeError) do
      @user_csv_import.stubs(:local_csv_file_path).returns("bad_filename")
      CsvImporter::DataProcessor.new(@user_csv_import, @organization, @options)
    end
    assert_equal "Where is the csv?", error.message
    error = assert_raise(RuntimeError) do
      @user_csv_import.stubs(:local_csv_file_path).returns("test/fixtures/files/handbook_test.txt")
      CsvImporter::DataProcessor.new(@user_csv_import, @organization, @options)
    end
    assert_equal "The file is not a csv", error.message
  end

  def test_suspended_member_emails
    suspended_member = @organization.members.first
    suspended_member.update_attribute(:state, Member::Status::SUSPENDED)
    suspended_member.update_attribute(:email, "ALL@CAPS.COM")
    dp = CsvImporter::DataProcessor.new(@user_csv_import, @organization, @options)
    assert dp.send(:suspended_member_emails).include?("all@caps.com")
  end

  def test_all_member_emails
    member = @organization.members.first
    member.update_attribute(:email, "ALL@CAPS.COM")
    dp = CsvImporter::DataProcessor.new(@user_csv_import, @organization, @options)
    assert dp.send(:all_member_emails).include?("all@caps.com")
  end

  def test_all_user_emails
    member = members(:f_admin)
    member.update_attribute(:email, "ALL@CAPS.COM")
    dp = CsvImporter::DataProcessor.new(@user_csv_import, @organization.reload, @options)
    dp.send(:all_user_emails).include?("all@caps.com")
  end

  def test_program_level
    dp = CsvImporter::DataProcessor.new(@user_csv_import, @organization.reload, @options)
    assert dp.send(:program_level?)

    @options[:program] = nil
    dp = CsvImporter::DataProcessor.new(@user_csv_import, @organization.reload, @options)
    assert_false dp.send(:program_level?)
  end

  def test_cannot_add_organization_members
    dp = CsvImporter::DataProcessor.new(@user_csv_import, @organization.reload, @options)
    assert dp.send(:cannot_add_organization_members?)

    dp = CsvImporter::DataProcessor.new(@user_csv_import, @organization.reload, {})
    assert_false dp.send(:cannot_add_organization_members?)
  end

  def test_get_processed_rows
    dp = CsvImporter::DataProcessor.new(@user_csv_import, @organization.reload, @options)
    dp.stubs(:get_processed_information).with(1,5).once.returns("one")
    dp.stubs(:get_processed_information).with(2,6).once.returns("two")
    assert_equal ["one", "two"], dp.send(:get_processed_rows, [1,2], [5,6])
  end

  def test_get_processed_information
    dp = CsvImporter::DataProcessor.new(@user_csv_import, @organization.reload, @options)
    dp.stubs(:get_role).with(1).returns("role")
    dp.stubs(:get_errors).with(1, "role").returns("error")
    dp.stubs(:is_suspended_member?).with(1).returns("suspended")
    dp.stubs(:will_update_user?).with(1).returns("update")
    dp.stubs(:get_program_level_information).with(1, "role").returns(["state", "invite"])
    pr = dp.send(:get_processed_information, 1, 2)
    assert_equal "error", pr.errors
    assert_equal "suspended", pr.is_suspended_member
    assert_equal "update", pr.user_to_be_updated
    assert_equal "state", pr.state
    assert_equal "invite", pr.user_to_be_invited
  end

  def test_get_program_level_information
    dp = CsvImporter::DataProcessor.new(@user_csv_import, @organization.reload, @options)
    dp.stubs(:get_state).with(1,2).once.returns("one")
    dp.stubs(:will_invite_user?).with(1).once.returns("two")
    assert_equal ["one", "two"], dp.send(:get_program_level_information, 1, 2)
  end

  def test_get_errors
    dp = CsvImporter::DataProcessor.new(@user_csv_import, @organization.reload, @options)
    dp.validator = CsvImporter::Validator.new(nil, nil, nil, nil, nil)
    CsvImporter::Validator.any_instance.stubs(:validate_row).with(1,2).returns("Something")
    assert_equal "Something", dp.send(:get_errors, 1,2)
  end

  def test_get_state
    dp = CsvImporter::DataProcessor.new(@user_csv_import, @organization.reload, @options)
    dp.validator = CsvImporter::Validator.new(nil, nil, nil, nil, nil)
    CsvImporter::Validator.any_instance.stubs(:all_mandatory_questions_answered?).with(1,2).returns(true)
    assert_equal User::Status::ACTIVE, dp.send(:get_state, 1,2)
    CsvImporter::Validator.any_instance.stubs(:all_mandatory_questions_answered?).with(1,3).returns(false)
    assert_equal User::Status::PENDING, dp.send(:get_state, 1,3)
  end

  def test_is_suspended_member
    dp = CsvImporter::DataProcessor.new(@user_csv_import, @organization.reload, @options)
    dp.stubs(:suspended_member_emails).returns(["one", "two", "three"])
    assert_false dp.send(:is_suspended_member?, {})
    assert dp.send(:is_suspended_member?, {UserCsvImport::CsvMapColumns::EMAIL.to_sym => "one"})
    assert_false dp.send(:is_suspended_member?, {UserCsvImport::CsvMapColumns::EMAIL.to_sym => "four"})
  end

  def test_will_invite_user
    dp = CsvImporter::DataProcessor.new(@user_csv_import, @organization.reload, @options)
    dp.stubs(:all_member_emails).returns(["one", "two", "three"])
    dp.stubs(:all_user_emails).returns(["one", "two"])
    dp.stubs(:cannot_add_organization_members?).returns(true)
    assert dp.send(:will_invite_user?, {UserCsvImport::CsvMapColumns::EMAIL.to_sym => "three"})
    assert_false dp.send(:will_invite_user?, {UserCsvImport::CsvMapColumns::EMAIL.to_sym => "one"})
    assert_false dp.send(:will_invite_user?, {})

    dp.stubs(:cannot_add_organization_members?).returns(false)
    assert_false dp.send(:will_invite_user?, {UserCsvImport::CsvMapColumns::EMAIL.to_sym => "three"})
  end

  def test_will_update_user
    dp = CsvImporter::DataProcessor.new(@user_csv_import, @organization.reload, @options)
    dp.stubs(:all_member_emails).returns(["one", "two", "three"])
    dp.stubs(:all_user_emails).returns(["one", "two"])
    assert dp.send(:will_update_user?, {UserCsvImport::CsvMapColumns::EMAIL.to_sym => "one"})
    assert_false dp.send(:will_update_user?, {UserCsvImport::CsvMapColumns::EMAIL.to_sym => "three"})

    dp.stubs(:program_level?).returns(false)
    assert dp.send(:will_update_user?, {UserCsvImport::CsvMapColumns::EMAIL.to_sym => "one"})
    assert dp.send(:will_update_user?, {UserCsvImport::CsvMapColumns::EMAIL.to_sym => "three"})
  end

  def test_compute_result
    dp = CsvImporter::DataProcessor.new(@user_csv_import, @organization.reload, @options)
    pr1 = CsvImporter::ProcessedRow.new(1, "something")
    pr2 = CsvImporter::ProcessedRow.new(2, "something")
    pr3 = CsvImporter::ProcessedRow.new(3, "something")
    pr4 = CsvImporter::ProcessedRow.new(4, "something")
    pr1.stubs(:can_show_errors?).returns(true)
    pr2.stubs(:can_show_errors?).returns(false)
    pr3.stubs(:can_show_errors?).returns(false)
    pr4.stubs(:can_show_errors?).returns(false)


    pr1.stubs(:is_suspended_member?).returns(false)
    pr2.stubs(:is_suspended_member?).returns(true)
    pr3.stubs(:is_suspended_member?).returns(true)
    pr4.stubs(:is_suspended_member?).returns(true)

    pr1.stubs(:is_user_to_be_updated?).returns(false)
    pr2.stubs(:is_user_to_be_updated?).returns(false)
    pr3.stubs(:is_user_to_be_updated?).returns(true)
    pr4.stubs(:is_user_to_be_updated?).returns(true)

    pr1.stubs(:is_user_to_be_added?).returns(false)
    pr2.stubs(:is_user_to_be_added?).returns(false)
    pr3.stubs(:is_user_to_be_added?).returns(false)
    pr4.stubs(:is_user_to_be_added?).returns(true)

    pr1.stubs(:to_be_imported?).returns(true)
    pr2.stubs(:to_be_imported?).returns(true)
    pr3.stubs(:to_be_imported?).returns(true)
    pr4.stubs(:to_be_imported?).returns(true)

    processed_rows = [pr1, pr2, pr3, pr4]

    dp.stubs(:program_level_result).with(processed_rows).once.returns({:invited_users => 5, :something => "something else"})
    result = dp.send(:compute_result, processed_rows)
    assert_equal 1, result[:errors_count]
    assert_equal 3, result[:suspended_members]
    assert_equal 2, result[:updated_users]
    assert_equal 1, result[:total_added]
    assert_equal 5, result[:invited_users]
    assert_equal 4, result[:imported_users]
    assert_equal "something else", result[:something]

    dp.stubs(:program_level?).returns(false)
    result = dp.send(:compute_result, processed_rows)
    assert_equal 1, result[:errors_count]
    assert_equal 3, result[:suspended_members]
    assert_equal 2, result[:updated_users]
    assert_equal 1, result[:total_added]
    assert_equal 4, result[:imported_users]
    assert_nil result[:invited_users]
    assert_nil result[:something]
  end

  def test_program_level_result
    dp = CsvImporter::DataProcessor.new(@user_csv_import, @organization.reload, @options)

    pr1 = CsvImporter::ProcessedRow.new(1, "something")
    pr2 = CsvImporter::ProcessedRow.new(2, "something")
    pr3 = CsvImporter::ProcessedRow.new(3, "something")
    pr4 = CsvImporter::ProcessedRow.new(4, "something")
    pr1.stubs(:active_profile?).returns(true)
    pr2.stubs(:active_profile?).returns(true)
    pr3.stubs(:active_profile?).returns(true)
    pr4.stubs(:active_profile?).returns(true)


    pr1.stubs(:pending_profile?).returns(false)
    pr2.stubs(:pending_profile?).returns(true)
    pr3.stubs(:pending_profile?).returns(true)
    pr4.stubs(:pending_profile?).returns(true)

    pr1.stubs(:is_user_to_be_invited?).returns(false)
    pr2.stubs(:is_user_to_be_invited?).returns(false)
    pr3.stubs(:is_user_to_be_invited?).returns(true)
    pr4.stubs(:is_user_to_be_invited?).returns(true)

    processed_rows = [pr1, pr2, pr3, pr4]

    result = dp.send(:program_level_result, processed_rows)
    assert_equal 4, result[:active_profiles]
    assert_equal 3, result[:pending_profiles]
    assert_equal 2, result[:invited_users]
  end

  def test_csv_emails_count
    dp = CsvImporter::DataProcessor.new(@user_csv_import, @organization.reload, @options)
    dp.stubs(:all_records).with([1,2], UserCsvImport::CsvMapColumns::EMAIL.to_sym).returns("something")
    assert_equal "something", dp.send(:csv_emails_count, [1,2])
  end

  def test_csv_uuid_occurance_count
    custom_auth = @organization.auth_configs.create!(auth_type: AuthConfig::Type::SAML)
    members(:f_admin).login_identifiers.create!(auth_config: custom_auth, identifier: "a")
    members(:f_mentor).login_identifiers.create!(auth_config: custom_auth, identifier: "b")

    dp = CsvImporter::DataProcessor.new(@user_csv_import, @organization.reload, @options)
    result = { "a" => 3, "b" => 1, "c" => 1, "d" => 0, "e" => 0 }
    assert_equal result, dp.send(:csv_uuid_occurance_count, [{uuid: "a", email: "one"}, {uuid: "a", email: "two"}, {uuid: "c", email: "three"}, {uuid: "d", email: ""}, {uuid: "e", email: nil}, {uuid: "B", email: members(:f_mentor).email}, {}])
  end

  def test_all_records
    dp = CsvImporter::DataProcessor.new(@user_csv_import, @organization.reload, @options)
    hash = dp.send(:all_records, [{"one" => "Something"}, {"one" => "something", "two" => "One thing"}, {"one" => "something else", "two" => "Another thing"}], "one")
    assert_equal 2, hash.size
    assert_equal 2, hash["something"]
    assert_equal 1, hash["something else"]

    hash = dp.send(:all_records, [{"one" => "Something"}, {"one" => "something", "two" => "One thing"}, {"one" => "something else", "two" => "Another thing"}], "two")
    assert_equal 3, hash.size
    assert_equal 1, hash["one thing"]
    assert_equal 1, hash[""]
    assert_equal 1, hash["another thing"]
  end

  def test_process
    dp = CsvImporter::DataProcessor.new(@user_csv_import, @organization.reload, @options)
    SmarterCSV.stubs(:process).with(@filename, CsvImporter::Constants::CSV_OPTIONS.merge(key_mapping: @col_mapping)).returns([{:first_name => "Alan", :last_name => "Smith" },{:first_name => nil, :last_name => ""}])
    SmarterCSV.stubs(:process).with(@filename, CsvImporter::Constants::CSV_OPTIONS.merge(keep_original_headers: true)).returns([{:first_name => "Bob", :last_name => "Smith" },{:first_name => nil, :last_name => ""}])
    CsvImporter::Cache.stubs(:write).with(@user_csv_import, "processed rows").returns
    dp.stubs(:csv_emails_count).with([{:first_name => "Alan", :last_name => "Smith" }]).returns("e")
    dp.stubs(:csv_uuid_occurance_count).with([{:first_name => "Alan", :last_name => "Smith" }]).returns("u")
    CsvImporter::Validator.stubs(:new).with(@organization, @options[:program], "e", "u", @options[:profile_questions]).returns("v")
    dp.stubs(:get_processed_rows).with([{:first_name => "Alan", :last_name => "Smith" }], [{:first_name => "Bob", :last_name => "Smith" }]).returns("processed rows")
    dp.stubs(:compute_result).with("processed rows").returns("result")
    assert_equal "result", dp.process
  end
end