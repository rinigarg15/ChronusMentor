  # encoding: utf-8
require_relative './../test_helper.rb'

class UserCsvImportTest < ActiveSupport::TestCase

  def setup
    super
    program = programs(:albers)

    @user_csv_import = program.user_csv_imports.new
    @user_csv_import.member = members(:f_admin)
    @user_csv_import.attachment = fixture_file_upload("/files/csv_import.csv", "text/csv")
    @user_csv_import.save!

    @user_csv_import.update_attribute(:local_csv_file_path, UserCsvImport.save_user_csv_to_be_imported(fixture_file_upload("/files/csv_import.csv", "text/csv").read, "csv_import.csv", @user_csv_import.id))
  end

  def test_local_csv_file_path
    @user_csv_import.update_attribute(:local_csv_file_path, "some random path")
    @user_csv_import.reload
    assert_false File.exists?("some random path")

    assert_not_equal @user_csv_import.local_csv_file_path, "some random path"
    assert File.exists?(@user_csv_import.local_csv_file_path)
  end

  def test_handle_file_encoding
    file_path = Rails.root.to_s + "/test/fixtures/files/csv_import.csv"

    old_encoding = `file -b --mime-encoding #{file_path}`.strip
    assert UserCsvImport.handle_file_encoding(file_path, @user_csv_import.id)
    
    # changing encoding
    system("iconv -f #{old_encoding} -t UTF-16 #{file_path} -o #{file_path}")

    old_encoding = `file -b --mime-encoding #{file_path}`.strip

    assert_equal "utf-16le", old_encoding
    assert UserCsvImport.handle_file_encoding(file_path, @user_csv_import.id)

    new_encoding = `file -b --mime-encoding #{file_path}`.strip

    assert_equal "utf-8", new_encoding

    # forcefully changing back to original encoding
    system("iconv -c -f utf-8 -t us-ascii #{file_path} -o #{file_path}")
  end

  def test_save_csv_file
    program = programs(:albers)

    UserCsvImport.stubs(:handle_file_encoding).returns(false)
    user_csv_import, valid_encoding = UserCsvImport.save_csv_file(program, members(:f_admin), fixture_file_upload("/files/csv_import.csv", "application/octet-stream"))

    assert_false valid_encoding
    assert_equal user_csv_import.program, program
    assert_equal user_csv_import.member, members(:f_admin)
    assert_equal user_csv_import.attachment_file_name, "csv_import.csv"
    assert_not_nil user_csv_import.local_csv_file_path
  end

  def test_save_user_csv_to_be_imported_and_clean_up_user_csv_file
    csv_import_csv_file_headers = [:first_name, :last_name, :email, :roles, :location, :language, :uuid]
    file_path = UserCsvImport.save_user_csv_to_be_imported(fixture_file_upload("/files/csv_import.csv", "text/csv").read, "csv_import.csv", @user_csv_import.id)

    assert File.exist?(file_path)

    assert_equal SmarterCSV.process(file_path).last.keys, csv_import_csv_file_headers

    UserCsvImport.clean_up_user_csv_file(file_path)

    assert_false File.exist?(file_path)
  end

  def test_column_key_dropdown_heading
    org = programs(:org_primary)

    pq = org.profile_questions.first
    profile_column_key = UserCsvImport::CsvMapColumns::PROFILE_QUESTION_COLUMN_KEY.call(pq.id)
    assert_equal UserCsvImport.column_key_dropdown_heading(profile_column_key), pq.question_text

    non_profile_column_key = UserCsvImport::CsvMapColumns::FIRST_NAME
    assert UserCsvImport::CsvMapColumns.non_profile_columns.include?(non_profile_column_key)
    assert_equal UserCsvImport.column_key_dropdown_heading(non_profile_column_key), "First Name"
  end

  def test_csv_content
    assert_equal @user_csv_import.csv_content, SmarterCSV.process(@user_csv_import.local_csv_file_path, CsvImporter::Constants::CSV_OPTIONS)
  end

  def test_example_column_values
    expected_result = {"0"=>"eg: Alan, Michael", "1"=>"eg: Smith, Brian", "2"=>"eg: alan@gmail.com, michael@gmail.com", "3"=>"eg: mentor, mentee", "4"=>"eg: Russia", "5"=> "eg: English, English", "6" => "eg: 12345666, 12345677"}
    assert_equal expected_result, @user_csv_import.example_column_values
  end

  def test_csv_headers_for_dropdown
    assert_equal @user_csv_import.csv_headers_for_dropdown, ["First Name", "Last Name", "Email", "Roles", "Location", "language", "UUID"]
  end

  def test_map_non_mandatory_columns_keys
    pqs = programs(:albers).profile_questions_for_user_csv_import
    keys = pqs.map{ |pq| UserCsvImport::CsvMapColumns::PROFILE_QUESTION_COLUMN_KEY.call(pq.id) }
    assert_equal @user_csv_import.map_non_mandatory_columns_keys(nil), keys + [UserCsvImport::CsvMapColumns::DONT_MAP]

    keys << UserCsvImport::CsvMapColumns::UUID
    keys << UserCsvImport::CsvMapColumns::DONT_MAP
    assert_equal @user_csv_import.map_non_mandatory_columns_keys(nil, is_super_console: true), keys
  end

  def test_map_mandatory_column_keys
    assert_equal @user_csv_import.map_mandatory_column_keys(true, nil), ["first_name", "last_name", "email", "roles"]

    assert_equal @user_csv_import.map_mandatory_column_keys(true, [RoleConstants::MENTOR_NAME]), ["first_name", "last_name", "email"]
  end

  def test_save_mapping_params
    csv_dropdown_choices = {"0"=>"1", "1"=>"2", "2"=>"6", "3"=>"3", "4"=>"4", "5"=>"5", "6"=>"7", "7"=>"8"}

    profile_dropdown_choices = {"3"=>"profile_question_9", "4"=>"profile_question_33", "5"=>"profile_question_10", "6"=>"profile_question_206", "7"=>UserCsvImport::CsvMapColumns::DONT_MAP}

    assert_equal @user_csv_import.info_hash, {}

    @user_csv_import.stubs(:process_params).with(csv_dropdown_choices, profile_dropdown_choices).returns("something")
    @user_csv_import.save_mapping_params(csv_dropdown_choices, profile_dropdown_choices)

    @user_csv_import.reload

    assert_equal_hash @user_csv_import.info_hash, {"csv_dropdown_choices"=> csv_dropdown_choices, "profile_dropdown_choices" => profile_dropdown_choices, "processed_params" => "something"}
  end

  def test_save_processed_csv_import_params
    assert_equal @user_csv_import.info_hash, {}

    @user_csv_import.stubs(:get_header_and_key_mapping).returns("something")

    @user_csv_import.save_processed_csv_import_params

    @user_csv_import.reload

    assert_equal_hash @user_csv_import.info_hash, {"processed_csv_import_params" => "something"}
  end

  def test_csv_column_to_field_mapping_and_field_to_csv_column_mapping
    csv_dropdown_choices = {"0"=>"0", "1"=>"1", "2"=>"2", "3"=>"3", "4"=>"4", "5"=>"5", "6"=>"7", "7"=>"8"}

    profile_dropdown_choices = {"3"=>"profile_question_9", "4"=>"profile_question_33", "5"=>"profile_question_10", "6"=>"profile_question_206", "7"=>UserCsvImport::CsvMapColumns::UUID}

    @user_csv_import.update_or_save_role([RoleConstants::MENTOR_NAME])

    @user_csv_import.save_mapping_params(csv_dropdown_choices, profile_dropdown_choices)

    @user_csv_import.reload

    assert_equal @user_csv_import.info_hash, {"roles" => [RoleConstants::MENTOR_NAME], "csv_dropdown_choices"=> csv_dropdown_choices, "profile_dropdown_choices" => profile_dropdown_choices, "processed_params" => {"0"=>"first_name","1"=>"last_name","2"=>"email","3"=>"profile_question_9","4"=>"profile_question_33","5"=>"profile_question_10","7"=>"profile_question_206","8"=>"uuid"}}

    assert_equal @user_csv_import.csv_column_to_field_mapping, {:first_name=>"first_name", :last_name=>"last_name", :email=>"email", :roles=>"profile_question_9", :location=>"profile_question_33", :language=>"profile_question_10", :uuid => nil}

    assert_equal @user_csv_import.field_to_csv_column_mapping, {"first_name"=>"First Name", "last_name"=>"Last Name", "email"=>"Email", "profile_question_9"=>"Roles", "profile_question_33"=>"Location", "profile_question_10"=>"language", nil => "UUID"}
  end

  def test_instruction_message_for_map_column
    profile_questions = [profile_questions(:education_q), profile_questions(:experience_q), profile_questions(:publication_q), profile_questions(:manager_q)]

    Program.any_instance.stubs(:profile_questions_for_user_csv_import).returns(profile_questions)

    assert_equal @user_csv_import.instruction_message_for_map_column(nil), "Map the columns from CSV to the fields in your program. Here are some tips:<ol><li>Please note the program fields which are marked * must be present in the CSV.</li><li>Please note that fields of type Education, Experience, Publication and Manage cannot be imported.</li></ol>"

    profile_questions = [profile_questions(:education_q), profile_questions(:experience_q)]

    Program.any_instance.stubs(:profile_questions_for_user_csv_import).returns(profile_questions)

    assert_equal @user_csv_import.instruction_message_for_map_column(nil), "Map the columns from CSV to the fields in your program. Here are some tips:<ol><li>Please note the program fields which are marked * must be present in the CSV.</li><li>Please note that fields of type Education and Experience cannot be imported.</li></ol>"

    profile_questions = [profile_questions(:education_q)]

    Program.any_instance.stubs(:profile_questions_for_user_csv_import).returns(profile_questions)

    assert_equal @user_csv_import.instruction_message_for_map_column(nil), "Map the columns from CSV to the fields in your program. Here are some tips:<ol><li>Please note the program fields which are marked * must be present in the CSV.</li><li>Please note that fields of type Education cannot be imported.</li></ol>"
  end

  def test_validations
    user_csv_import = UserCsvImport.new

    assert_false user_csv_import.valid?

    assert_equal user_csv_import.errors[:program_id], ["can't be blank"]

    user_csv_import.program = programs(:albers)

    assert_equal user_csv_import.errors[:member_id], ["can't be blank"]

    user_csv_import.member = members(:f_admin)

    assert_equal user_csv_import.errors[:attachment], ["can't be blank"]

    user_csv_import.attachment = fixture_file_upload("/files/csv_import.csv", "text/csv")

    assert user_csv_import.valid?
  end

  def test_info_hash
    assert_equal @user_csv_import.info_hash, {}

    @user_csv_import.info = {1 => 2}.to_yaml
    @user_csv_import.save!

    assert_equal @user_csv_import.info_hash, {1 => 2}
  end

  def test_update_or_save_role
    assert_equal @user_csv_import.info_hash, {}

    @user_csv_import.update_or_save_role([RoleConstants::MENTOR_NAME])

    assert_equal @user_csv_import.info_hash, {"roles" => [RoleConstants::MENTOR_NAME]}
  end

  def test_get_header_and_key_mapping
    csv_headers = ["First name", "last name", "email", "p1", "p2"]
    empty_hash = {}

    user_csv_import = programs(:albers).user_csv_imports.new
    user_csv_import.member = members(:f_admin)
    user_csv_import.attachment = fixture_file_upload("/files/csv_import.csv", "text/csv")
    user_csv_import.save!

    user_csv_import.stubs(:csv_headers_for_dropdown).returns(csv_headers)

    expected_header_and_key_mapping = {}

    user_csv_import.info = empty_hash.to_yaml
    user_csv_import.save!

    assert_equal_hash empty_hash, user_csv_import.get_header_and_key_mapping

    user_csv_import.info = {:processed_params => {"0" => "first_name", "1" => "last_name", "2" => "email", "3" => "profile_question_1", "4" => "profile_question_2"}}.to_yaml
    user_csv_import.save!

    expected_header_and_key_mapping = {"First name" => "first_name", "last name" => "last_name", "email" => "email", "p1" => "profile_question_1", "p2" => "profile_question_2"}

    assert_equal_hash expected_header_and_key_mapping, user_csv_import.get_header_and_key_mapping
  end

  def test_get_processed_saved_mapping
    csv_column_headers = ["First name", "last name", "email", "p1", "p2"]
    mandatory_column_keys = ["first_name", "last_name", "email"]

    session_stored_mapping = {}
    user_csv_import_mapping = {}
    expected_processed_mapping = {}
    assert_equal_hash expected_processed_mapping, UserCsvImport.get_processed_saved_mapping(session_stored_mapping, user_csv_import_mapping, csv_column_headers, mandatory_column_keys)

    session_stored_mapping = {"First name" => "first_name", "last name" => "last_name", "email" => "email", "Roles" => "roles", "p1" => "", "p2" => "profile_question_1", "p3" => "profile_question_2", "p4" => ""}
    user_csv_import_mapping = {}
    expected_processed_mapping = {"p2" => "profile_question_1", "First name" => "first_name", "last name" => "last_name", "email" => "email", "p1" => ""}
    assert_equal_hash expected_processed_mapping, UserCsvImport.get_processed_saved_mapping(session_stored_mapping, user_csv_import_mapping, csv_column_headers, mandatory_column_keys)

    session_stored_mapping = {"First name" => "first_name", "Last Name" => "last_name", "Roles" => "roles", "p1" => "", "p2" => "profile_question_1", "p3" => "profile_question_2", "p4" => ""}
    user_csv_import_mapping = {"First name" => "first_name", "last name" => "last_name", "email" => "email", "p1" => "profile_question_1", "p2" => "profile_question_3"}
    expected_processed_mapping = {"First name" => "first_name", "last name" => "last_name", "email" => "email", "p1" => "profile_question_1", "p2" => "profile_question_3"}
    assert_equal_hash expected_processed_mapping, UserCsvImport.get_processed_saved_mapping(session_stored_mapping, user_csv_import_mapping, csv_column_headers, mandatory_column_keys)

    session_stored_mapping = {"First name" => "first_name", "Last Name" => "last_name", "email" => "email", "Roles" => "roles", "p1" => "", "p2" => "profile_question_1", "p3" => "profile_question_2", "p4" => ""}
    user_csv_import_mapping = {"First name" => "first_name", "last name" => "last_name", "email" => "", "p1" => "profile_question_1", "p2" => "profile_question_3"}
    expected_processed_mapping = {}
    assert_equal_hash expected_processed_mapping, UserCsvImport.get_processed_saved_mapping(session_stored_mapping, user_csv_import_mapping, csv_column_headers, mandatory_column_keys)
  end

  def test_selected_roles
    assert_nil @user_csv_import.selected_roles

    @user_csv_import.update_or_save_role([RoleConstants::MENTOR_NAME])

    assert_equal @user_csv_import.selected_roles, [RoleConstants::MENTOR_NAME]
  end

  def test_original_csv_headers
    assert_equal @user_csv_import.original_csv_headers, @user_csv_import.csv_headers_for_dropdown
  end
end